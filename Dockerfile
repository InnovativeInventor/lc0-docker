FROM nvidia/cuda:10.0-cudnn7-runtime as lc0base
RUN apt-get update &&\
    apt-get install -y libopenblas-base libprotobuf10 zlib1g-dev \
    ocl-icd-libopencl1 tzdata &&\
    apt-get clean all

FROM lc0base as botbase
RUN apt-get update &&\
    apt-get install -y python3.8 &&\
    apt-get clean all

FROM nvidia/cuda:10.0-cudnn7-devel as builder
RUN apt-get update &&\
    apt-get install -y curl wget supervisor git \
    clang-6.0 libopenblas-dev ninja-build protobuf-compiler libprotobuf-dev \
    python3-pip &&\
    apt-get clean all
RUN pip3 install meson

LABEL "version"="lc0_v0.26.3-client_v29"
RUN curl -s -L https://github.com/LeelaChessZero/lc0/releases/latest |\
    egrep -o '/LeelaChessZero/lc0/archive/v.*.tar.gz' |\
    wget --base=https://github.com/ -O lc0latest.tgz -i - &&\
    tar xfz lc0latest.tgz && rm lc0latest.tgz && mv lc0* /lc0
WORKDIR /lc0
RUN CC=clang-6.0 CXX=clang++-6.0 INSTALL_PREFIX=/lc0 \
    ./build.sh release && ls /lc0/bin
WORKDIR /lc0/bin
RUN curl -s -L https://github.com/LeelaChessZero/lczero-client/releases/latest |\
    egrep -o '/LeelaChessZero/lczero-client/releases/download/v.*/lc0-training-client-linux' |\
    head -n 1 | wget --base=https://github.com/ -i - &&\
    chmod +x lc0-training-client-linux &&\
    mv lc0-training-client-linux lc0client

FROM lc0base as lc0
COPY --from=builder /lc0/bin /lc0/bin
WORKDIR /lc0/bin
ENV PATH=/lc0/bin:$PATH
CMD lc0client --user lc0docker --password lc0docker

FROM builder as botBuilder
RUN apt-get update &&\
    apt-get install -y python3.8-venv python3-venv
RUN git clone https://github.com/careless25/lichess-bot.git /lcbot
WORKDIR /lcbot
RUN python3.8 -m venv .venv &&\
    . .venv/bin/activate &&\
    pip3 install wheel &&\
    pip3 install -r requirements.txt

FROM botbase as lcbot
COPY --from=builder /lc0/bin /lc0/bin
COPY --from=botBuilder /lcbot /lcbot

ENV PATH /lc0/bin:$PATH
WORKDIR /lcbot
