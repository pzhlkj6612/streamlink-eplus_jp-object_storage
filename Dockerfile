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
        'https://github.com/s3tools/s3cmd/archive/bff5ad5ccbe6c156118cdb6f4632dd454f4a7cdc.zip'

RUN curl -L 'https://aka.ms/InstallAzureCLIDeb' | bash

# python - Can I force pip to make a shallow checkout when installing from git? - Stack Overflow
#   https://stackoverflow.com/a/52989760
RUN pip install \
        --disable-pip-version-check \
        --no-cache-dir \
        --upgrade \
        'https://github.com/streamlink/streamlink/archive/44c4a4c5dc63b7ca865294cd651ffea1f472fc00.zip'

# git - How to shallow clone a specific commit with depth 1? - Stack Overflow
#   https://stackoverflow.com/a/43136160
RUN mkdir '/SL-plugins' && \
    git -C '/SL-plugins' init && \
    git -C '/SL-plugins' remote add 'origin' 'https://github.com/pmrowla/streamlink-plugins.git' && \
    git -C '/SL-plugins' fetch --depth=1 'origin' 'd249172869b176ec1317500a6816e43d6b9ae6e2' && \
    git -C '/SL-plugins' switch --detach 'FETCH_HEAD'

RUN mkdir -p '/opt/ffmpeg' && \
    curl -L 'https://github.com/BtbN/FFmpeg-Builds/releases/download/autobuild-2022-10-29-12-37/ffmpeg-n5.1.2-4-gf5455889fd-linux64-gpl-shared-5.1.tar.xz' | \
        tar -C '/opt/ffmpeg' -f- -x --xz --strip-components=1

ENV PATH="/opt/ffmpeg/bin:${PATH}"

VOLUME [ "/SL-downloads" ]

COPY --chown=0:0 --chmod=700 ./script.sh /script.sh

ENTRYPOINT [ "/script.sh" ]
