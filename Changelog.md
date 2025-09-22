# Changelog

### 2025.03.06

#### Breaking:

- file `/YTDLP/cookies.txt` was moved to `/opt/config/cookies.txt`
- directory `/SL-plugins` was moved to `/opt/config/SL-plugins`
- directory `/SL-downalods` was moved to `/opt/config/SL-downloads`
- `ENABLE_S3` and related environment were removed, you should use `ENABLE_RCLONE` instead
- `ENABLE_AZURE` and related environment were removed, you should use `ENABLE_RCLONE` instead

#### Feature:

- Introduce `rclone` as the file uploader, you can use `ENABLE_RCLONE` to use it.
- Introduce `N_m3u8DL-RE` as the optional stream downaloder.

#### Improvement:

- Reduce the size of the docker image
- Use yt-dlp standalone
- Use streamlink appimage
- All tools were placed in the folder `/opt/tools`

```tree
/opt/tools
|-- bin
|   |-- N_m3u8DL-RE
|   |-- mp4decrypt
|   |-- rclone
|   |-- streamlink
|   `-- yt-dlp
`-- ffmpeg
    |-- bin
    |   |-- ffmpeg
    |   `-- ffprobe
    `-- lib
```