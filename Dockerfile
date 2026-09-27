ARG BENTO4_BUILD_DIR=/tmp/cmakebuild

FROM ubuntu:jammy AS bento4-building

ARG BENTO4_BUILD_DIR

RUN apt update && \
    apt install \
    -y \
    --no-install-suggests \
    --no-install-recommends \
    'ca-certificates' 'libarchive-tools' 'curl' 'make' 'cmake' 'build-essential'

# current HEAD
RUN curl -L 'https://github.com/axiomatic-systems/Bento4/archive/b8c50a078356a1c3444ce0a8744634ed488424a4.zip' | \
        bsdtar -f- -x --strip-components=1 && \
    mkdir -p ${BENTO4_BUILD_DIR} && \
    cd ${BENTO4_BUILD_DIR} && \
    cmake -DCMAKE_BUILD_TYPE=Release "${OLDPWD}" && \
    make mp4decrypt -j2


FROM ubuntu:jammy

RUN apt update && \
    apt install \
        -y \
        --no-install-suggests \
        --no-install-recommends \
        'ca-certificates' 'curl' 'git' 'python3-pip' 'xz-utils' && \
    python3 -m pip install pip -U

# v2.4.0
RUN pip install \
        --disable-pip-version-check \
        --no-cache-dir \
        --force-reinstall \
        'https://github.com/s3tools/s3cmd/archive/9d17075b77e933cf9d7916435c426d38ab5bca5e.zip'

RUN curl -L 'https://aka.ms/InstallAzureCLIDeb' | bash

# python - Can I force pip to make a shallow checkout when installing from git? - Stack Overflow
#   https://stackoverflow.com/a/52989760
#
# 8.5.0
RUN pip install \
        --disable-pip-version-check \
        --no-cache-dir \
        --force-reinstall \
        'https://github.com/streamlink/streamlink/archive/4aa0943390abf2818c9289bca17e2d27d67d4713.zip'

# 2026.08.19
RUN pip install \
        --disable-pip-version-check \
        --no-cache-dir \
        --force-reinstall \
        'https://github.com/yt-dlp/yt-dlp/archive/3a08beaf031ab68f966401ead017ac81fe8486cf.zip'

RUN mkdir '/opt/n_m3u8dl_re' && \
    if [ "$(uname -m)" = 'x86_64' ]; then \
        n_m3u8dl_re_url='https://github.com/nilaoda/N_m3u8DL-RE/releases/download/v0.6.0-beta/N_m3u8DL-RE_v0.6.0-beta_linux-x64_20260629.tar.gz'; \
    else \
        n_m3u8dl_re_url='https://github.com/nilaoda/N_m3u8DL-RE/releases/download/v0.6.0-beta/N_m3u8DL-RE_v0.6.0-beta_linux-arm64_20260629.tar.gz'; \
    fi && \
    curl -L "${n_m3u8dl_re_url}" | \
        tar -C '/opt/n_m3u8dl_re' -f- -x --gzip && \
    chmod u+x '/opt/n_m3u8dl_re/N_m3u8DL-RE'

ARG BENTO4_BUILD_DIR
COPY --from='bento4-building' ${BENTO4_BUILD_DIR}/mp4decrypt '/opt/n_m3u8dl_re/mp4decrypt'

# git - How to shallow clone a specific commit with depth 1? - Stack Overflow
#   https://stackoverflow.com/a/43136160
#
# current HEAD
RUN mkdir '/SL-plugins' && \
    git -C '/SL-plugins' init && \
    git -C '/SL-plugins' remote add 'origin' 'https://github.com/pmrowla/streamlink-plugins.git' && \
    git -C '/SL-plugins' fetch --depth=1 'origin' 'dd4c258b096218575ade1d6e698f9fecda2d4e27' && \
    git -C '/SL-plugins' switch --detach 'FETCH_HEAD'

RUN mkdir '/opt/ffmpeg' && \
    if [ "$(uname -m)" = 'x86_64' ]; then \
        ffmpeg_url='https://github.com/BtbN/FFmpeg-Builds/releases/download/autobuild-2026-09-26-13-03/ffmpeg-n9.0.2-10-g51c4a23d74-linux64-gpl-9.0.tar.xz'; \
    else \
        ffmpeg_url='https://github.com/BtbN/FFmpeg-Builds/releases/download/autobuild-2026-09-26-13-03/ffmpeg-n9.0.2-10-g51c4a23d74-linuxarm64-gpl-9.0.tar.xz'; \
    fi && \
    curl -L "${ffmpeg_url}" | \
        tar -C '/opt/ffmpeg' -f- -x --xz --strip-components=1

ENV PATH="/opt/ffmpeg/bin:/opt/n_m3u8dl_re:${PATH}"

VOLUME [ "/SL-downloads" ]

# for cookies.txt
RUN mkdir '/YTDLP'

COPY --chown=0:0 --chmod=700 ./script.sh /script.sh

ENTRYPOINT [ "/script.sh" ]
