FROM ubuntu:focal

RUN apt update && \
    apt install \
        -y \
        --no-install-suggests \
        --no-install-recommends \
        'curl' 'git' 'python3-pip' 'xz-utils'

RUN pip install \
        --disable-pip-version-check \
        --no-cache-dir \
        --upgrade \
        'https://github.com/s3tools/s3cmd/archive/9d17075b77e933cf9d7916435c426d38ab5bca5e.zip'

RUN curl -L 'https://aka.ms/InstallAzureCLIDeb' | bash

# python - Can I force pip to make a shallow checkout when installing from git? - Stack Overflow
#   https://stackoverflow.com/a/52989760
RUN pip install \
        --disable-pip-version-check \
        --no-cache-dir \
        --upgrade \
        'https://github.com/streamlink/streamlink/archive/010364de80e3555b293c9fdd8a57e26c79e16751.zip'

RUN pip install \
        --disable-pip-version-check \
        --no-cache-dir \
        --upgrade \
        'https://github.com/pzhlkj6612/yt-dlp-fork/archive/1ae004981909676efec00d2df4235d0d002849f4.zip'

# git - How to shallow clone a specific commit with depth 1? - Stack Overflow
#   https://stackoverflow.com/a/43136160
RUN mkdir '/SL-plugins' && \
    git -C '/SL-plugins' init && \
    git -C '/SL-plugins' remote add 'origin' 'https://github.com/pmrowla/streamlink-plugins.git' && \
    git -C '/SL-plugins' fetch --depth=1 'origin' 'b9cedb6a6257d5f0f5274d08551b3079fc4560dc' && \
    git -C '/SL-plugins' switch --detach 'FETCH_HEAD'

RUN mkdir -p '/opt/ffmpeg' && \
    curl -L 'https://github.com/BtbN/FFmpeg-Builds/releases/download/autobuild-2023-12-08-13-13/ffmpeg-n6.0.1-1-g133069b434-linux64-gpl-shared-6.0.tar.xz' | \
        tar -C '/opt/ffmpeg' -f- -x --xz --strip-components=1

ENV PATH="/opt/ffmpeg/bin:${PATH}"

VOLUME [ "/SL-downloads" ]

# for cookies.txt
RUN mkdir '/YTDLP'

COPY --chown=0:0 --chmod=700 ./script.sh /script.sh

ENTRYPOINT [ "/script.sh" ]
