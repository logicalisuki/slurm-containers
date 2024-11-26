#FROM ubuntu:24.04
#RUN apt-get update -y &&  apt-get install build-essential fakeroot devscripts equivs wget -y
##downloading and installing a version of slurm
#RUN wget https://download.schedmd.com/slurm/slurm-24.11.0-0rc2.tar.bz2 && tar -xaf slurm-24.11.0-0rc2.tar.bz2 && cd slurm-24.11.0-0rc2 && mk-build-deps -i debian/control && debuild -b -uc -us 
# Base Image for Slurm Compilation
FROM ubuntu:24.04 AS slurm-base

# Install dependencies for building Slurm
RUN apt-get update && apt-get install -y \
    build-essential \
    curl \
    libmunge-dev \
    munge \
    libssl-dev \
    libpam0g-dev \
    python-is-python3 \
    mariadb-client \
    mariadb-server \
    libmariadb-dev-compat \
    libmariadb-dev && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Set Slurm version
ARG SLURM_VERSION=24.05.4

# Download and compile Slurm
WORKDIR /tmp
RUN curl -LO https://download.schedmd.com/slurm/slurm-${SLURM_VERSION}.tar.bz2 && \
    tar -xjf slurm-${SLURM_VERSION}.tar.bz2 && \
    cd slurm-${SLURM_VERSION} && \
    ./configure --prefix=/usr/local/slurm && \
    make -j$(nproc) && \
    make install && \
    rm -rf /tmp/slurm-${SLURM_VERSION}*

# Add Slurm to PATH
ENV PATH="/usr/local/slurm/bin:/usr/local/slurm/sbin:$PATH"

