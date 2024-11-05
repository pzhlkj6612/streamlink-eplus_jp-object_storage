ARG BENTO4_BUILD_DIR=/tmp/cmakebuild

FROM ubuntu:jammy AS bento4-building

ARG BENTO4_BUILD_DIR

RUN apt update && \
    apt install \
    -y \
    --no-install-suggests \
    --no-install-recommends \
    'libarchive-tools' 'curl' 'make' 'cmake' 'build-essential'

RUN curl -L 'https://github.com/axiomatic-systems/Bento4/archive/f8ce9a93de14972a9ddce442917ddabe21456f4d.zip' | \
        bsdtar -f- -x --strip-components=1

RUN mkdir -p ${BENTO4_BUILD_DIR} && \
    cd ${BENTO4_BUILD_DIR} && \
    cmake -DCMAKE_BUILD_TYPE=Release .. && \
    make mp4decrypt -j2


FROM ubuntu:jammy

RUN apt update && \
    apt install \
        -y \
        --no-install-suggests \
        --no-install-recommends \
        'curl' 'git' 'python3-pip' 'xz-utils' && \
    python3 -m pip install pip -U

RUN pip install \
        --disable-pip-version-check \
        --no-cache-dir \
        --force-reinstall \
        'https://github.com/s3tools/s3cmd/archive/9d17075b77e933cf9d7916435c426d38ab5bca5e.zip'

RUN curl -L 'https://aka.ms/InstallAzureCLIDeb' | bash

# python - Can I force pip to make a shallow checkout when installing from git? - Stack Overflow
#   https://stackoverflow.com/a/52989760
RUN pip install \
        --disable-pip-version-check \
        --no-cache-dir \
        --force-reinstall \
        'https://github.com/streamlink/streamlink/archive/a25de3b26d0f35103811e104c82e8b9eeadb4555.zip'

RUN pip install \
        --disable-pip-version-check \
        --no-cache-dir \
        --force-reinstall \
        'https://github.com/yt-dlp/yt-dlp/archive/a065086640e888e8d58c615d52ed2f4f4e4c9d18.zip'

RUN mkdir '/opt/n_m3u8dl_re' && \
    if [ "$(uname -m)" = 'x86_64' ]; then \
        n_m3u8dl_re_url='https://github.com/nilaoda/N_m3u8DL-RE/releases/download/v0.2.1-beta/N_m3u8DL-RE_Beta_linux-x64_20240828.tar.gz'; \
    else \
        n_m3u8dl_re_url='https://github.com/nilaoda/N_m3u8DL-RE/releases/download/v0.2.1-beta/N_m3u8DL-RE_Beta_linux-arm64_20240828.tar.gz'; \
    fi && \
    curl -L "${n_m3u8dl_re_url}" | \
        tar -C '/opt/n_m3u8dl_re' -f- -x --xz --strip-components=1 && \
    chmod u+x '/opt/n_m3u8dl_re/N_m3u8DL-RE'

ARG BENTO4_BUILD_DIR
COPY --from='bento4-building' ${BENTO4_BUILD_DIR}/mp4decrypt '/opt/n_m3u8dl_re/mp4decrypt'

# git - How to shallow clone a specific commit with depth 1? - Stack Overflow
#   https://stackoverflow.com/a/43136160
RUN mkdir '/SL-plugins' && \
    git -C '/SL-plugins' init && \
    git -C '/SL-plugins' remote add 'origin' 'https://github.com/pmrowla/streamlink-plugins.git' && \
    git -C '/SL-plugins' fetch --depth=1 'origin' 'fa794c0bd23a6439be9ec313ed71b4050339c752' && \
    git -C '/SL-plugins' switch --detach 'FETCH_HEAD'

RUN mkdir '/opt/ffmpeg' && \
    if [ "$(uname -m)" = 'x86_64' ]; then \
        ffmpeg_url='https://github.com/BtbN/FFmpeg-Builds/releases/download/autobuild-2024-11-05-13-03/ffmpeg-n7.1-16-g15035aaec0-linux64-gpl-7.1.tar.xz'; \
    else \
        ffmpeg_url='https://github.com/BtbN/FFmpeg-Builds/releases/download/autobuild-2024-11-05-13-03/ffmpeg-n7.1-16-g15035aaec0-linuxarm64-gpl-7.1.tar.xz'; \
    fi && \
    curl -L "${ffmpeg_url}" | \
        tar -C '/opt/ffmpeg' -f- -x --xz --strip-components=1

ENV PATH="/opt/ffmpeg/bin:/opt/n_m3u8dl_re:${PATH}"

VOLUME [ "/SL-downloads" ]

# for cookies.txt
RUN mkdir '/YTDLP'

COPY --chown=0:0 --chmod=700 ./script.sh /script.sh

ENTRYPOINT [ "/script.sh" ]
