#FROM ubuntu:24.04
#RUN apt-get update -y &&  apt-get install build-essential fakeroot devscripts equivs wget -y
##downloading and installing a version of slurm
#RUN wget https://download.schedmd.com/slurm/slurm-24.11.0-0rc2.tar.bz2 && tar -xaf slurm-24.11.0-0rc2.tar.bz2 && cd slurm-24.11.0-0rc2 && mk-build-deps -i debian/control && debuild -b -uc -us 
# Base Image for Slurm Compilation
FROM ubuntu:24.04 AS slurm-base

# Install dependencies for building Slurm
# Install dependencies for building Slurm and required PAM modules
RUN apt-get update && apt-get install -y \
    build-essential \
    curl \
    libjson-c-dev \
    libhttp-parser-dev \
    libmunge-dev \
    libmunge2 \
    munge \
    libssl-dev \
    libpam0g-dev \
    python-is-python3 \
    openssl \
    openssh-client \
    libjwt-dev \
    vim \
    sssd \
    mariadb-client \
    mariadb-server \
    libmariadb-dev-compat \
    gosu \
    tzdata \
    libpam-modules \
    libpam-modules-bin && \
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
    ./configure --prefix=/usr/local/slurm  --with-jwt --with-http-parser --with-json --with-curl --enable-slurmrestd && \
    make -j$(nproc) && \
    make install && \
    rm -rf /tmp/slurm-${SLURM_VERSION}*

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

