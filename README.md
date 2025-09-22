# Streamlink, eplus.jp and Object Storage

> DMCA is coming...?

## What does this docker image do

- Download the live streaming or VOD from [eplus](https://ib.eplus.jp/) and other websites via Streamlink, yt-dlp or N_m3u8DL-RE.
- Upload the video file under your control with tool `rclone`.

## Details

### Storage requirement

For a 4-hour live event, the size of a MPEG-TS recording with the best quality is about 9.88 GB (9.2 GiB).

### Downloader support

The support of yt-dlp & N_m3u8DL-RE is experimental.

### Output

The output file is in ".ts" format. I believe that your media player is smart enough to get to know the actual codec.

The file is located in the "/opt/downloads" directory in the container. You are able to access those files by mounting a volume into that directory **before** creating the container (otherwise you may have to play with [`docker cp`](https://docs.docker.com/reference/cli/docker/container/cp/) or anonymous volumes).

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

#### Rclone preparation

> Remember to correctly set up the Docker volume mapping.

Environment variables:

| Name | Description
| - | -
| ENABLE_RCLONE | The flag to enable rclone feature.
| RCLONE_CONFIG_PATH | The path to your rclone config file, for example `/tmp/rclone.conf`

Prepare your own rclone provider:

> offical config example: https://rclone.org/#providers

```conf
[sshserver]
type = sftp
host = example.com
user = sftpuser
key_file = ~/id_rsa
pubkey_file = ~/id_rsa-cert.pub

[amazon-s3]
type = s3
provider = LyveCloud
access_key_id = XXX
secret_access_key = YYY
endpoint = s3.us-east-1.lyvecloud.seagate.com
```

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
      - ./downloads:/opt/downloads:rw
      - ./ytb.txt:/opt/config/cookies.txt:rw  # edit "cookies.txt" in it
      - ./streamlink.AppImage:/opt/tools/bin/streamlink.AppImage
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
      - N_m3u8DL_RE_FFMPEG_OPTIONS=  # set environment variable for RE_LIVE_PIPE_OPTIONS, for more details: https://github.com/nilaoda/N_m3u8DL-RE/blob/30499f5f87e9470e051036946c95620f0774a0d2/src/N_m3u8DL-RE/Util/PipeUtil.cs#L49C63-L49C83
                                     # the default value is: " -f flv -flvflags no_duration_filesize ", output pipe is handled inside
                                     # if you wan't exclude some stream, for example, you can set " -map -0:d -c copy -f flv " to exclude data stream

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

      - ENABLE_RCLONE=       # enable rclone

      # rclone
      - RCLONE_CONFIG_PATH=/path/to/rclone.conf

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
        path: ./downloads
        type: Directory
  restartPolicy: Never
  containers:
    - name: sl
      image: docker.io/pzhlkj6612/streamlink-eplus_jp-object_storage
      resources: {}
      volumeMounts:
        - mountPath: /opt/downloads
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
  - [rclone/rclone](https://github.com/rclone/rclone).
  - [streamlink/streamlink](https://github.com/streamlink/streamlink) and [pmrowla/streamlink-plugins](https://github.com/pmrowla/streamlink-plugins).
  - [yt-dlp/yt-dlp](https://github.com/yt-dlp/yt-dlp)
  - [nilaoda/N_m3u8DL-RE](https://github.com/nilaoda/N_m3u8DL-RE)
  - [BtbN/FFmpeg-Builds](https://github.com/BtbN/FFmpeg-Builds).
  - I used to format my bash shell script with [shell-format - Visual Studio Marketplace](https://marketplace.visualstudio.com/items?itemName=foxundermoon.shell-format).
- Platforms:
  - [Stack Exchange](https://stackexchange.com/) website group.
  - Linux and Debian.

## Further to do

- [ ] Use alpine as the base image to decrese the image size.