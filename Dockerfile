FROM ubuntu:24.04 AS slurm-base

# Install build and runtime dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    curl \
    wget \
    libmunge-dev \
    libmunge2 \
    munge \
    libssl-dev \
    libpam0g-dev \
    libpam-modules \
    libpam-sss \
    libpam-modules-bin \
    libjwt-dev \
    libjson-c-dev \
    libhttp-parser-dev \
    libjansson-dev \
    openssl \
    python-is-python3 \
    openssh-client \
    vim \
    sssd \
    mariadb-client \
    mariadb-server \
    libmariadb-dev-compat \
    gosu \
    tzdata \
    krb5-user \
    ca-certificates && \
    yes | unminimize && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Set Slurm version
ARG SLURM_VERSION=24.11.1

# Set timezone
RUN ln -sf /usr/share/zoneinfo/Europe/London /etc/localtime

# Build and install Slurm
WORKDIR /tmp
RUN curl -LO https://download.schedmd.com/slurm/slurm-${SLURM_VERSION}.tar.bz2 && \
    tar -xjf slurm-${SLURM_VERSION}.tar.bz2 && cd slurm-${SLURM_VERSION} && \
    ./configure \
      --prefix=/usr/local/slurm \
      --with-jwt \
      --with-http-parser \
      --with-curl \
      --enable-slurmrestd > /tmp/configure.log 2>&1 || (cat /tmp/configure.log && false) && \
    make -j$(nproc) && make install && \
    rm -rf /tmp/slurm-${SLURM_VERSION}*

# Create config directory
RUN mkdir -p /usr/local/slurm/etc

# Add entrypoint
COPY ./files/entrypoint.sh /usr/local/bin/entrypoint.sh
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]

ENV PATH="/usr/local/slurm/bin:/usr/local/slurm/sbin:$PATH"
