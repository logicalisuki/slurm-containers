# Base Image for Slurm Compilation from Nvidia
FROM nvidia/cuda:12.9.0-devel-ubuntu24.04 AS slurm-base
ENV TZ=Europe/London
ENV DEBIAN_FRONTEND=noninteractive
# Install dependencies for building Slurm and required PAM modules
RUN apt-get update && apt-get install -y  --no-install-recommends\
    libnss-wrapper \
    build-essential \
    curl \
    libjson-c-dev \
    libhttp-parser-dev \
    libmunge-dev \
    libmunge2 \
    libjansson-dev \
    munge \
    libssl-dev \
    libpam0g-dev \
    python-is-python3 \
    openssl \
    openssh-client \
    libjwt-dev \
    sssd \
    mariadb-client \
    mariadb-server \
    libmariadb-dev-compat \
    gosu \
    tzdata \
    libpam-modules \
    libpam-sss \
    ca-certificates \
    krb5-user \
    libpam-modules-bin && \
    yes | unminimize && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Set Slurm version
ARG SLURM_VERSION=24.11.1

# Ensure the munge group and user exist
RUN getent group munge || groupadd -r munge && \
    id -u munge || useradd -r -g munge munge

#TIME with DLS
RUN rm -rf /etc/localtime && ln -sf /usr/share/zoneinfo/Europe/London /etc/localtime

# Create directories and set ownership
RUN /bin/bash -c "mkdir -p /run/munge && chown munge:munge /run/munge" \
    && /bin/bash -c "mkdir -p /var/run/munge && chown munge:munge /var/run/munge" \
    && /bin/bash -c "mkdir -p /var/{spool,run}/{slurmd,slurmctld,slurmdbd}/" \
    && /bin/bash -c "mkdir -p /var/log/{slurm,slurmctld,slurmdbd}/"

# Download and compile Slurm
WORKDIR /tmp
RUN curl -LO https://download.schedmd.com/slurm/slurm-${SLURM_VERSION}.tar.bz2 && \
    tar -xjf slurm-${SLURM_VERSION}.tar.bz2 && \
    cd slurm-${SLURM_VERSION} && \
    ./configure --prefix=/usr/local/slurm  --with-jwt --with-http-parser --with-curl --with-mysql --enable-slurmrestd > /tmp/configure.log 2>&1 || (cat /tmp/configure.log && false) && \
    make -j$(nproc) && \
    make install && \
    rm -rf /tmp/slurm-${SLURM_VERSION}*


RUN apt-get purge -y \
    build-essential \
    libjson-c-dev \
    libhttp-parser-dev \
    libjansson-dev \
    libssl-dev \
    libpam0g-dev \
    libjwt-dev \
    libmariadb-dev-compat \
 && apt-get autoremove -y && apt-get clean && rm -rf /var/lib/apt/lists/*

# Ensure the slurm group and user exist
RUN getent group slurm || groupadd -r slurm && \
    id -u slurm || useradd -r -g slurm slurm

# Install kubectl
RUN curl -LO https://storage.googleapis.com/kubernetes-release/release/$(curl -s https://storage.googleapis.com/kubernetes-release/release/stable.txt)/bin/linux/amd64/kubectl
RUN chmod +x ./kubectl
RUN mv ./kubectl /usr/local/bin/kubectl

# Create slurm default config folder
RUN /bin/bash -c "mkdir -p /usr/local/slurm/etc && chown slurm:slurm /usr/local/slurm/etc"

# Add Entrypoint 
ADD ./files/entrypoint.sh /usr/local/bin/entrypoint.sh
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]

# Add Slurm to PATH
ENV PATH="/usr/local/slurm/bin:/usr/local/slurm/sbin:$PATH"

