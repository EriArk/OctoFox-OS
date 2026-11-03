# SPDX-License-Identifier: GPL-3.0-or-later
# Developer-only ARM64 cross build; never installed on a handheld.
FROM ubuntu:24.04@sha256:fe81560990fae86dc4743202b2cb4d3df98d0bcf949173cecef15ce1127ef852
ENV DEBIAN_FRONTEND=noninteractive
RUN dpkg --add-architecture arm64 \
 && sed -i '/^Types:/a Architectures: amd64' /etc/apt/sources.list.d/ubuntu.sources \
 && printf 'deb [arch=arm64] http://ports.ubuntu.com/ubuntu-ports noble main universe\ndeb [arch=arm64] http://ports.ubuntu.com/ubuntu-ports noble-updates main universe\ndeb [arch=arm64] http://ports.ubuntu.com/ubuntu-ports noble-security main universe\n' > /etc/apt/sources.list.d/arm64.list \
 && apt-get update \
 && apt-get install -y --no-install-recommends build-essential gcc-aarch64-linux-gnu g++-aarch64-linux-gnu binutils-aarch64-linux-gnu cmake ninja-build pkg-config python3 git ca-certificates zip unzip file zlib1g-dev:arm64 libpng-dev:arm64 libyaml-dev:arm64 libsdl2-dev:arm64 libgl-dev:arm64 libreadline-dev:arm64 \
 && dpkg-query -W -f='${binary:Package}\t${Version}\n' > /toolchain-packages.tsv \
 && rm -rf /var/lib/apt/lists/*
ENV PKG_CONFIG_LIBDIR=/usr/lib/aarch64-linux-gnu/pkgconfig:/usr/share/pkgconfig
ENV CC=aarch64-linux-gnu-gcc CXX=aarch64-linux-gnu-g++ AR=aarch64-linux-gnu-ar STRIP=aarch64-linux-gnu-strip
RUN apt-get update \
 && apt-get install -y --no-install-recommends libboost-dev:arm64 qemu-user \
 && dpkg-query -W -f='${binary:Package}\t${Version}\n' > /toolchain-packages.tsv \
 && rm -rf /var/lib/apt/lists/*
ENV QEMU_LD_PREFIX=/usr/aarch64-linux-gnu
RUN apt-get update \
 && apt-get install -y --no-install-recommends xxd \
 && dpkg-query -W -f='${binary:Package}\t${Version}\n' > /toolchain-packages.tsv \
 && rm -rf /var/lib/apt/lists/*
