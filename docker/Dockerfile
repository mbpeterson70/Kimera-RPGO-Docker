FROM ubuntu:24.04

# Avoid interactive tzdata configuration
ENV DEBIAN_FRONTEND=noninteractive

# Install only what's needed to build and run
RUN apt-get update && \
    apt-get upgrade -y && \
    apt-get install -q -y --no-install-recommends \
        ca-certificates git cmake g++ make libboost-all-dev && \
    rm -rf /var/lib/apt/lists/*

WORKDIR /root

# Install gtsam
RUN git clone https://github.com/borglab/gtsam.git ./gtsam
WORKDIR /root/gtsam
RUN git checkout 686e16aaae26c9a4f23d4af7f2d4a504125ec9c3
RUN mkdir build
WORKDIR /root/gtsam/build
RUN cmake .. -DGTSAM_POSE3_EXPMAP=ON -DGTSAM_ROT3_EXPMAP=ON
RUN make -j"$(nproc)" install && ldconfig

# Copy and build Kimera-RPGO
COPY . /root/Kimera-RPGO-Docker
RUN mkdir -p /root/Kimera-RPGO-Docker/build
WORKDIR /root/Kimera-RPGO-Docker/build
RUN cmake .. && make -j"$(nproc)" && \
    echo "/root/Kimera-RPGO-Docker/build" > /etc/ld.so.conf.d/kimera-rpgo.conf && \
    ldconfig

# Allow non-root users (via --user) to access the binaries and libraries
RUN chmod o+rx /root && chmod -R o+rX /root/Kimera-RPGO-Docker/build

ENV PATH="/root/Kimera-RPGO-Docker/build:${PATH}"
