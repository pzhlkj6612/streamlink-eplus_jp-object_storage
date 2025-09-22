ARG BENTO4_BUILD_DIR=/tmp/cmakebuild
ARG TOOLS_DIR=/opt/tools
ARG CONFIG_DIR=/opt/config

FROM python:3.13.1-slim-bookworm AS builder

ARG BENTO4_BUILD_DIR
ARG TOOLS_DIR

RUN apt update && \
    apt install \
    -y \
    --no-install-suggests \
    --no-install-recommends \
    'ca-certificates' 'libarchive-tools' 'curl' 'make' 'cmake' 'build-essential'

RUN mkdir -p "${TOOLS_DIR}/bin"

# Bento4: Commits on Sep 16, 2024 - GitHub
RUN curl -L 'https://github.com/axiomatic-systems/Bento4/archive/f8ce9a93de14972a9ddce442917ddabe21456f4d.zip' | \
        bsdtar -f- -x --strip-components=1 && \
    mkdir -p ${BENTO4_BUILD_DIR} && \
    cd ${BENTO4_BUILD_DIR} && \
    cmake -DCMAKE_BUILD_TYPE=Release "${OLDPWD}" && \
    make mp4decrypt -j2 && \
    cp "${BENTO4_BUILD_DIR}/mp4decrypt" "${TOOLS_DIR}/bin/mp4decrypt"

# # yt-dlp builder
# RUN mkdir 'yt-dlp' && \
#     curl -L "https://github.com/yt-dlp/yt-dlp/archive/refs/tags/2024.12.13.tar.gz" | \
#         tar -C 'yt-dlp' -f- -x --gzip --strip-components=1 && \
#     cd 'yt-dlp' && \
#     python3 -m venv .venv-yt-dlp && . .venv-yt-dlp/bin/activate && \
#     python3 devscripts/install_deps.py --include pyinstaller && \
#     python3 devscripts/make_lazy_extractors.py && \
#     python3 -m bundle.pyinstaller && \
#     cp 'dist/yt-dlp_linux' "${TOOLS_DIR}/bin/yt-dlp"

# yt-dlp standalone

RUN if [ "$(uname -m)" = 'x86_64' ]; then \
        yt_dlp_url='https://github.com/yt-dlp/yt-dlp/releases/download/2025.02.19/yt-dlp_linux'; \
    else \
        yt_dlp_url='https://github.com/yt-dlp/yt-dlp/releases/download/2025.02.19/yt-dlp_linux_aarch64'; \
    fi && \
    curl -L "${yt_dlp_url}" -o "${TOOLS_DIR}/bin/yt-dlp" && \
    chmod u+x "${TOOLS_DIR}/bin/yt-dlp"

# N_m3u8DL-RE binary
RUN if [ "$(uname -m)" = 'x86_64' ]; then \
        n_m3u8dl_re_url='https://github.com/nilaoda/N_m3u8DL-RE/releases/download/v0.2.1-beta/N_m3u8DL-RE_Beta_linux-x64_20240828.tar.gz'; \
    else \
        n_m3u8dl_re_url='https://github.com/nilaoda/N_m3u8DL-RE/releases/download/v0.2.1-beta/N_m3u8DL-RE_Beta_linux-arm64_20240828.tar.gz'; \
    fi && \
    curl -L "${n_m3u8dl_re_url}" | \
        tar -C "${TOOLS_DIR}/bin" -f- -x --gzip --strip-components=1 && \
    chmod u+x "${TOOLS_DIR}/bin/N_m3u8DL-RE"

# ffmpeg binaries
RUN mkdir -p "${TOOLS_DIR}/ffmpeg" && \
    if [ "$(uname -m)" = 'x86_64' ]; then \
        ffmpeg_url='https://github.com/BtbN/FFmpeg-Builds/releases/download/autobuild-2024-12-31-13-02/ffmpeg-n7.1-62-gb168ed9b14-linux64-gpl-shared-7.1.tar.xz'; \
    else \
        ffmpeg_url='https://github.com/BtbN/FFmpeg-Builds/releases/download/autobuild-2024-12-31-13-02/ffmpeg-n7.1-62-gb168ed9b14-linuxarm64-gpl-shared-7.1.tar.xz'; \
    fi && \
    curl -L "${ffmpeg_url}" | \
        tar -C "${TOOLS_DIR}/ffmpeg" -f- -x --xz --strip-components=1 && \
    rm "${TOOLS_DIR}/ffmpeg/bin/ffplay" && \
    rm -rf "${TOOLS_DIR}/ffmpeg/doc" "${TOOLS_DIR}/ffmpeg/man" "${TOOLS_DIR}/ffmpeg/include" "${TOOLS_DIR}/ffmpeg/LICENSE.txt"

# streamlink appimage
# python - Can I force pip to make a shallow checkout when installing from git? - Stack Overflow
#   https://stackoverflow.com/a/52989760
RUN if [ "$(uname -m)" = 'x86_64' ]; then \
        streamlink_appimage_url='https://github.com/streamlink/streamlink-appimage/releases/download/7.1.3-1/streamlink-7.1.3-1-cp313-cp313-manylinux_2_28_x86_64.AppImage'; \
    else \
        streamlink_appimage_url='https://github.com/streamlink/streamlink-appimage/releases/download/7.1.3-1/streamlink-7.1.3-1-cp313-cp313-manylinux_2_28_aarch64.AppImage'; \
    fi && \
    curl -L "${streamlink_appimage_url}" -o "${TOOLS_DIR}/bin/streamlink.AppImage" && \
        chmod u+x "${TOOLS_DIR}/bin/streamlink.AppImage"

# rclone binary
RUN if [ "$(uname -m)" = 'x86_64' ]; then \
        rclone_url='https://github.com/rclone/rclone/releases/download/v1.69.1/rclone-v1.69.1-linux-amd64.zip'; \
    else \
        rclone_url='https://github.com/rclone/rclone/releases/download/v1.69.1/rclone-v1.69.1-linux-arm64.zip'; \
    fi && \
    curl -L "${rclone_url}" | \
        bsdtar -C "${TOOLS_DIR}/bin" -f- -x --strip-components=1 && \
    chmod u+x "${TOOLS_DIR}/bin/rclone" && \
    rm "${TOOLS_DIR}/bin/rclone.1"

# clean up
RUN rm ${TOOLS_DIR}/bin/README.* && rm ${TOOLS_DIR}/bin/*.txt

########################################################################################################################

FROM debian:bookworm-slim AS runner

ARG TOOLS_DIR
ARG CONFIG_DIR

RUN apt update && \
    apt install \
        -y \
        --no-install-suggests \
        --no-install-recommends \
        #       -           -      -      .NET
        'ca-certificates' 'curl' 'git' 'libicu72'

RUN mkdir -p "${TOOLS_DIR}/bin"
RUN mkdir -p "${CONFIG_DIR}"

COPY --from='builder' "${TOOLS_DIR}" "${TOOLS_DIR}"

# git - How to shallow clone a specific commit with depth 1? - Stack Overflow
#   https://stackoverflow.com/a/43136160
RUN mkdir "${CONFIG_DIR}/SL-plugins" && \
    git -C "${CONFIG_DIR}/SL-plugins" init && \
    git -C "${CONFIG_DIR}/SL-plugins" remote add 'origin' 'https://github.com/pmrowla/streamlink-plugins.git' && \
    git -C "${CONFIG_DIR}/SL-plugins" fetch --depth=1 'origin' 'fa794c0bd23a6439be9ec313ed71b4050339c752' && \
    git -C "${CONFIG_DIR}/SL-plugins" switch --detach 'FETCH_HEAD'

ENV PATH="${TOOLS_DIR}/ffmpeg/bin:${TOOLS_DIR}/bin:${PATH}"
ENV LD_LIBRARY_PATH="${TOOLS_DIR}/ffmpeg/lib:${LD_LIBRARY_PATH}"

VOLUME [ "/opt/downloads" ]

COPY --chown=0:0 --chmod=700 ./script.sh /script.sh

ENTRYPOINT [ "/script.sh" ]
