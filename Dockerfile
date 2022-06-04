FROM ubuntu:focal

COPY --chown=0:0 --chmod=700 ./script.sh /script.sh

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
        'https://github.com/s3tools/s3cmd/archive/a1bb8431456ac16c5dd0640a08865ca223838872.zip'

RUN curl -L 'https://aka.ms/InstallAzureCLIDeb' | bash

# python - Can I force pip to make a shallow checkout when installing from git? - Stack Overflow
#   https://stackoverflow.com/q/52989272
RUN pip install \
        --disable-pip-version-check \
        --no-cache-dir \
        --upgrade \
        'https://github.com/streamlink/streamlink/archive/ebe0d7a2cc529cddf0cff54e56444f2720a76b4a.zip'

RUN git clone \
        --depth=1 -- \
        'https://github.com/pmrowla/streamlink-plugins' \
        '/SL-plugins'

RUN mkdir -p '/opt/ffmpeg' && \
    curl -L 'https://github.com/BtbN/FFmpeg-Builds/releases/download/autobuild-2022-04-02-12-33/ffmpeg-n5.0-52-ga50aa980eb-linux64-lgpl-shared-5.0.tar.xz' | \
        tar -C '/opt/ffmpeg' -f- -x --xz --strip-components=1

ENV PATH="/opt/ffmpeg/bin:${PATH}"

VOLUME [ "/SL-downloads" ]

ENTRYPOINT [ "/script.sh" ]
