#FROM ubuntu:24.04
#RUN apt-get update -y &&  apt-get install build-essential fakeroot devscripts equivs wget -y
##downloading and installing a version of slurm
#RUN wget https://download.schedmd.com/slurm/slurm-24.11.0-0rc2.tar.bz2 && tar -xaf slurm-24.11.0-0rc2.tar.bz2 && cd slurm-24.11.0-0rc2 && mk-build-deps -i debian/control && debuild -b -uc -us 
# Base Image for Slurm Compilation
FROM ubuntu:24.04 AS slurm-base
# Install dependencies for building Slurm
# Install dependencies for building Slurm and required PAM modules
RUN apt-get update && apt-get install -y  --no-install-recommends\
    libnss-wrapper \
    build-essential \
    curl \
    libjson-c-dev \
    libhttp-parser-dev \
    libmunge-dev \
    libmunge2 \
    libpam0g-dev \
    libssl-dev \
    libjson-c-dev \
    libjansson-dev \
    libhttp-parser-dev \
    libjwt-dev \
    libmariadb-dev-compat \
 && apt-get clean && rm -rf /var/lib/apt/lists/*

# Set timezone
RUN ln -sf /usr/share/zoneinfo/Europe/London /etc/localtime

# Set Slurm version
ARG SLURM_VERSION=24.11.1

# Build Slurm
WORKDIR /tmp
RUN curl -LO https://download.schedmd.com/slurm/slurm-${SLURM_VERSION}.tar.bz2 && \
    tar -xjf slurm-${SLURM_VERSION}.tar.bz2 && \
    cd slurm-${SLURM_VERSION} && \
    ./configure --prefix=/usr/local/slurm --with-jwt --with-http-parser --with-curl --with-mysql --enable-slurmrestd > /tmp/configure.log 2>&1 || (cat /tmp/configure.log && false) && \
    make -j$(nproc) && make install && \
    cd / && rm -rf /tmp/slurm-${SLURM_VERSION}*

# Final clean-up (optional if multi-stage)
RUN apt-get purge -y \
    build-essential \
    libmunge-dev \
    libpam0g-dev \
    libssl-dev \
    libjson-c-dev \
    libjansson-dev \
    libhttp-parser-dev \
    libjwt-dev \
    libmariadb-dev-compat && \
    apt-get autoremove -y && apt-get clean && rm -rf /var/lib/apt/lists/*
