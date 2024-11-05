# Streamlink, eplus.jp and Object Storage

> DMCA is coming...?

## What does this docker image do

- Download the live streaming or VOD from [eplus](https://ib.eplus.jp/) and other websites via Streamlink, yt-dlp or N_m3u8DL-RE.
- Upload the video file to S3-compatible object storage via S3cmd or to Azure Storage container via Azure CLI.

## Details

### Storage requirement

For a 4-hour live event, the size of a MPEG-TS recording with the best quality is about 9.88 GB (9.2 GiB).

### Downloader support

The support of yt-dlp & N_m3u8DL-RE is experimental.

### Output

The output file is in ".ts" format. I believe that your media player is smart enough to get to know the actual codec.

The file is located in the "/SL-downloads" directory in the container. You are able to access those files by mounting a volume into that directory **before** creating the container (otherwise you may have to play with [`docker cp`](https://docs.docker.com/reference/cli/docker/container/cp/) or anonymous volumes).

You will see some intermediate files. Those files will be renamed to "final files" finally:

```shell
# template:
${datetime}.${OUTPUT_FILENAME_BASE}.ts # full
${OUTPUT_FILENAME_BASE}.ts             # NO_AUTO_PREFIX_DATETIME

# example:
'20220605T040302Z.name-1st-Otoyk-day0.ts' # full
'name-1st-Otoyk-day0.ts'                  # NO_AUTO_PREFIX_DATETIME

```

Final files:

```shell
# template:
${datetime}.${OUTPUT_FILENAME_BASE}.${size}.${md5}.ts # full
${OUTPUT_FILENAME_BASE}.${size}.${md5}.ts             # NO_AUTO_PREFIX_DATETIME
${datetime}.${OUTPUT_FILENAME_BASE}.${md5}.ts         # NO_AUTO_FILESIZE
${datetime}.${OUTPUT_FILENAME_BASE}.${size}.ts        # NO_AUTO_MD5

# example:
'20220605T040302Z.name-1st-Otoyk-day0.123456789.0123456789abcdef0123456789abcdef.ts' # full
'name-1st-Otoyk-day0.123456789.0123456789abcdef0123456789abcdef.ts'                  # NO_AUTO_PREFIX_DATETIME
'20220605T040302Z.name-1st-Otoyk-day0.0123456789abcdef0123456789abcdef.ts'           # NO_AUTO_FILESIZE
'20220605T040302Z.name-1st-Otoyk-day0.123456789.ts'                                  # NO_AUTO_MD5

```

| Variable | Description
| - | -
| OUTPUT_FILENAME_BASE | base file name (env)
| datetime | datetime at UTC in ISO 8601 format. <br> `strftime(${datetime}, 17, "%Y%m%dT%H%M%SZ", gmtime(&(time(0))))`
| size | file size. <br> `du -b "$filepath"`
| md5 | file hash. <br> `md5sum "$filepath"`

### Prepare your object storage

#### AWS S3-compatible preparation (simpler)

Create your own object storage:

- AWS:
  - [Creating, configuring, and working with Amazon S3 buckets - Amazon Simple Storage Service](https://docs.aws.amazon.com/AmazonS3/latest/userguide/creating-buckets-s3.html)
- DigitalOcean:
  - [How to Create Spaces :: DigitalOcean Documentation](https://docs.digitalocean.com/products/spaces/how-to/create/)
  - [Setting Up s3cmd 2.x with DigitalOcean Spaces :: DigitalOcean Documentation](https://docs.digitalocean.com/products/spaces/resources/s3cmd/)
- Linode:
  - [Object Storage - Get Started | Linode](https://www.linode.com/docs/products/storage/object-storage/get-started/)
  - [Deploy a Static Site using Hugo and Object Storage | Linode](https://www.linode.com/docs/guides/host-static-site-object-storage/)
- Vultr:
  - [Vultr Object Storage - Vultr.com](https://www.vultr.com/docs/vultr-object-storage)
- DreamObjects:
  - [DreamObjects overview – DreamHost Knowledge Base](https://help.dreamhost.com/hc/en-us/articles/214823108-DreamObjects-overview)
  - [Installing S3cmd – DreamHost Knowledge Base](https://help.dreamhost.com/hc/en-us/articles/215916627-Installing-S3cmd)

Environment variables:

| Name | Description
| - | -
| S3_BUCKET | URL in `s3://bucket-name/dir-name/` style
| S3_HOSTNAME | For example: <br> `s3-eu-west-1.amazonaws.com` <br> `nyc3.digitaloceanspaces.com` <br> `us-east-1.linodeobjects.com` <br> `ewr1.vultrobjects.com` <br> `objects-us-east-1.dream.io`
| AWS_ACCESS_KEY_ID | The access key
| AWS_SECRET_ACCESS_KEY | The secret key

#### Azure preparation

Create a service principal on Azure.

- [Create an Azure AD app and service principal in the portal - Microsoft identity platform | Microsoft Docs](https://docs.microsoft.com/en-us/azure/active-directory/develop/howto-create-service-principal-portal)
- [Create an Azure service principal – Azure CLI | Microsoft Docs](https://docs.microsoft.com/en-us/cli/azure/create-an-azure-service-principal-azure-cli)

For [`azure-cli`](https://docs.microsoft.com/en-us/cli/azure/install-azure-cli) :

```console
$ az login --use-device-code
$ az ad sp create-for-rbac --role 'Contributor' --name "${name}" --scopes "/subscriptions/${subscription}/resourceGroups/${resourceGroup}/providers/Microsoft.Storage/storageAccounts/${AZURE_STORAGE_ACCOUNT}"

```

Environment variables:

| Name | Description
| - | -
| AZ_SP_APPID | Application (client) ID
| AZ_SP_PASSWORD | Client secret
| AZ_SP_TENANT | Directory (tenant) ID
| AZURE_STORAGE_ACCOUNT | Azure storage account
| AZ_STORAGE_CONTAINER_NAME | Storage container name

### Launch the container

#### Docker

Install [Docker Engine](https://docs.docker.com/engine/) and use the [`docker compose`](https://docs.docker.com/engine/reference/commandline/compose/) command to manipulate Docker Compose.

Create a service:

```YAML
# docker-compose.yml

services:
  sl:
    image: docker.io/pzhlkj6612/streamlink-eplus_jp-object_storage
    volumes:
      - ./SL-downloads:/SL-downloads:rw
      - ./YTDLP:/YTDLP:rw  # edit "cookies.txt" in it
    environment:
      # base file name; will use a random one if leaving empty.
      - OUTPUT_FILENAME_BASE=

      # output file name configuration
      - NO_AUTO_PREFIX_DATETIME=
      - NO_AUTO_FILESIZE=
      - NO_AUTO_MD5=

      # Input control
      # only one input allowed; using file has the highest priority.

      # file
      # does NOT imply "NO_AUTO_PREFIX_DATETIME", "NO_AUTO_FILESIZE" and "NO_AUTO_MD5".
      # does imply "NO_DOWNLOAD_TS".
      - USE_EXISTING_MPEG_TS_VIDEO_FILE=

      # proxy for streamlink, yt-dlp and N_m3u8DL-RE
      - HTTPS_PROXY=http://127.0.0.1:1926  # empty by default.

      # streamlink
      - STREAMLINK_STREAM_URL=           # enable streamlink.
      - STREAMLINK_STREAM_QUALITY=       # "best" by default.
      - STREAMLINK_OPTIONS=              # options passed into streamlink after default ones; see https://streamlink.github.io/cli.html

      # yt-dlp
      - YTDLP_STREAM_URL=      # enable yt-dlp.
      - YTDLP_OPTIONS=         # options passed into yt-dlp after default ones; see https://github.com/yt-dlp/yt-dlp

      # N_m3u8DL-RE
      - N_m3u8DL_RE_STREAM_URL=      # enable N_m3u8DL-RE.
      - N_m3u8DL_RE_OPTIONS=         # options passed into N_m3u8DL-RE after default ones; see https://github.com/nilaoda/N_m3u8DL-RE

      # direct download
      - VIDEO_FILE_URL=  # download a video file.

      # ffmpeg
      - GENERATE_STILL_IMAGE_MPEG_TS=  # generate a still image MPEG-TS video.

      # Output control
      # multiple outputs supported.

      # file
      - NO_DOWNLOAD_TS=  # do not save the video file. it may not be a MPEG-TS file, but a MKV one.

      # rtmp
      - RTMP_TARGET_URL=     # enable RTMP streaming.
      - RTMP_FFMPEG_USE_AAC_ENCODING=      # enable audio re-encoding, otherwise just copy the stream.
      - RTMP_FFMPEG_USE_LIBX264_ENCODING=  # enable video re-encoding, otherwise just copy the stream.
      - RTMP_FFMPEG_CRF=     # CRF value for video re-encoding, 23 by default, see https://trac.ffmpeg.org/wiki/Encode/H.264#a1.ChooseaCRFvalue .

      # uploading control

      - ENABLE_S3=           # enable s3cmd.
      - ENABLE_AZURE=        # enable azure-cli.

      # s3cmd
      - AWS_ACCESS_KEY_ID=
      - AWS_SECRET_ACCESS_KEY=
      - S3_BUCKET=
      - S3_HOSTNAME=
      - S3CMD_MULTIPART_CHUNK_SIZE_MB=  # "--multipart-chunk-size-mb", 15 by default.

      # azure-cli
      - AZURE_STORAGE_ACCOUNT=
      - AZ_SP_APPID=
      - AZ_SP_PASSWORD=
      - AZ_SP_TENANT=
      - AZ_STORAGE_CONTAINER_NAME=

```

Run it:

```console
$ docker compose up sl

```

For developers who want to build the image themselves:

```console
$ docker build --tag ${tag} .

```

#### Podman

[Install Podman](https://podman.io/getting-started/installation). Create a pod and a "[hostPath](https://kubernetes.io/docs/concepts/storage/volumes/#hostpath)" volume:

```YAML
# pod.yaml

apiVersion: v1
kind: Pod
metadata:
  name: sl
spec:
  volumes:
    - name: SL-downloads
      hostPath:
        path: ./SL-downloads
        type: Directory
  restartPolicy: Never
  containers:
    - name: sl
      image: docker.io/pzhlkj6612/streamlink-eplus_jp-object_storage
      resources: {}
      volumeMounts:
        - mountPath: /SL-downloads
          name: SL-downloads
      env:
        # Please refer to the "Docker" section.
        - name: # ...
          value: # "..."

```

Finally, play it:

```console
$ podman play kube ./pod.yaml  # 開演！

```

For developers who want to build the image themselves:

```console
$ podman build --tag ${tag} .

```

## Credits

- Container Technologies:
  - Open Container Initiative (OCI).
  - Docker and Docker Compose.
  - Podman and Kubernetes.
- Useful open-source programs and tools:
  - [s3tools/s3cmd](https://github.com/s3tools/s3cmd).
  - [Azure/azure-cli](https://github.com/Azure/azure-cli).
  - [streamlink/streamlink](https://github.com/streamlink/streamlink) and [pmrowla/streamlink-plugins](https://github.com/pmrowla/streamlink-plugins).
  - [yt-dlp/yt-dlp](https://github.com/yt-dlp/yt-dlp)
  - [nilaoda/N_m3u8DL-RE](https://github.com/nilaoda/N_m3u8DL-RE)
  - [BtbN/FFmpeg-Builds](https://github.com/BtbN/FFmpeg-Builds).
  - I used to format my bash shell script with [shell-format - Visual Studio Marketplace](https://marketplace.visualstudio.com/items?itemName=foxundermoon.shell-format).
- Platforms:
  - AWS, DigitalOcean, Linode, Vultr and DreamHost.
  - Microsoft Azure.
  - [Stack Exchange](https://stackexchange.com/) website group.
  - Linux and Ubuntu.
