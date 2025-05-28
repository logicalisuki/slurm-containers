#!/bin/bash
set -euo pipefail

CMD="${1:-}"

function start_munge(){

    echo "---> Copying MUNGE key ..."
    cp /tmp/munge.key /etc/munge/munge.key
    chown munge:munge /etc/munge/munge.key

    echo "---> Starting the MUNGE Authentication service (munged) ..."
    gosu munge /usr/sbin/munged "$@"
}

if [ "$CMD" = "slurmdbd" ]
then

    start_munge

    echo "---> Starting the Slurm Database Daemon (slurmdbd) ..."

    cp /tmp/slurmdbd.conf /etc/slurm/slurmdbd.conf
    echo "StoragePass=${StoragePass}" >> /etc/slurm/slurmdbd.conf
    chown slurm:slurm /etc/slurm/slurmdbd.conf
    chmod 600 /etc/slurm/slurmdbd.conf
    {
        . /etc/slurm/slurmdbd.conf
        until echo "SELECT 1" | mysql -h $StorageHost -u$StorageUser -p$StoragePass 2>&1 > /dev/null
        do
            echo "-- Waiting for database to become active ..."
            sleep 2
        done
    }
    echo "-- Database is now active ..."

    exec gosu slurm /usr/sbin/slurmdbd -D "${@:2}"

elif [ "$CMD" = "slurmctld" ]
then

    start_munge

    echo "---> Waiting for slurmdbd to become active before starting slurmctld ..."

    until 2>/dev/null >/dev/tcp/slurmdbd/6819
    do
        echo "-- slurmdbd is not available.  Sleeping ..."
        sleep 2
    done
    echo "-- slurmdbd is now active ..."

    echo "---> Setting permissions for state directory ..."
    chown slurm:slurm /var/spool/slurmctld

    
    echo "---> Copying JWT key from mounted secret ..."
    mkdir -p /var/spool/slurm
    cp /etc/secrets/jwt_hs256.key /var/spool/slurm/jwt_hs256.key
    chown slurm:slurm /var/spool/slurm/jwt_hs256.key
    chmod 600 /var/spool/slurm/jwt_hs256.key
    SLURMCTLD=$(which slurmctld)

    echo "---> Starting the Slurm Controller Daemon (slurmctld) ..."
    if /usr/local/slurm/sbin/slurmctld -V | grep -q '17.02' ; then
        exec gosu slurm /usr/local/slurm/sbin/slurmctld -D "${@:2}"
    else
        exec gosu slurm /usr/local/slurm/sbin/slurmctld -i -D "${@:2}"
    fi

elif [ "$CMD" = "slurmd" ]
then
    echo "---> Set shell resource limits ..."
    ulimit -l unlimited
    ulimit -s unlimited
    ulimit -n 131072
    ulimit -a

    start_munge

    echo "---> Waiting for slurmctld to become active before starting slurmd..."

    until 2>/dev/null >/dev/tcp/slurmctld-0/6817
    do
        echo "-- slurmctld is not available.  Sleeping ..."
        sleep 2
    done
    echo "-- slurmctld is now active ..."

    echo "---> Starting the Slurm Node Daemon (slurmd) ..."
    exec /usr/sbin/slurmd -D "${@:2}"

elif [ "$CMD" = "login" ]
then
    
    chown root:root /home
    chmod 755 /home

    echo "---> Setting up SSH host keys (persistent on GPFS)..."
    if [ ! -f /etc/ssh/hostkeys-persist/ssh_host_rsa_key ]; then
        echo "---> No persistent SSH host keys found, generating them now..."
        ssh-keygen -A
        cp /etc/ssh/ssh_host_* /etc/ssh/hostkeys-persist/
    else
        echo "---> Found existing persistent SSH host keys, using them."
    fi

    echo "---> Copying persistent SSH host keys into /etc/ssh..."
    cp /etc/ssh/hostkeys-persist/* /etc/ssh/
    chmod 600 /etc/ssh/ssh_host_*_key

    echo "---> Setting up ssh for user"

    mkdir -p /home/rocky/.ssh
    cp /tmp/authorized_keys /home/rocky/.ssh/authorized_keys

    echo "---> Setting permissions for user home directories"
    pushd /home > /dev/null
    for DIR in *
        do
        chown -R $DIR:$DIR $DIR || echo "Failed to change ownership of $DIR"
        chmod 700 $DIR/.ssh || echo "Couldn't set permissions for .ssh/ directory of $DIR"
        chmod 600 $DIR/.ssh/authorized_keys || echo "Couldn't set permissions for .ssh/authorized_keys for $DIR"
    done
    popd > /dev/null

    echo "---> Complete"
    echo "---> Starting sshd"
    /usr/sbin/sshd

    start_munge

    echo "---> Setting up self ssh capabilities"

    if [ -f /home/rocky/.ssh/id_rsa.pub ]; then
        echo "ssh keys already found"
    else
        ssh-keygen -t rsa -f /home/rocky/.ssh/id_rsa -N ""
        chown rocky:rocky /home/rocky/.ssh/id_rsa /home/rocky/.ssh/id_rsa.pub
    fi

    ssh-keyscan localhost > /etc/ssh/ssh_known_hosts
    echo "" >> /home/rocky/.ssh/authorized_keys #Adding newline to avoid breaking authorized_keys file
    cat /home/rocky/.ssh/id_rsa.pub >> /home/rocky/.ssh/authorized_keys

elif [ "$CMD" = "check-queue-hook" ]
then
    start_munge

    scontrol update NodeName=all State=DRAIN Reason="Preventing new jobs running before upgrade"

    RUNNING_JOBS=$(squeue --states=RUNNING,COMPLETING,CONFIGURING,RESIZING,SIGNALING,STAGE_OUT,STOPPED,SUSPENDED --noheader --array | wc --lines)

    if [[ $RUNNING_JOBS -eq 0 ]]
    then
        exit 0
    else
        exit 1
    fi

elif [ "$CMD" = "undrain-nodes-hook" ]
then
    start_munge
    scontrol update NodeName=all State=UNDRAIN
    exit 0

elif [ "$CMD" = "generate-keys-hook" ]
then
    mkdir -p ./temphostkeys/etc/ssh
    ssh-keygen -A -f ./temphostkeys
    kubectl create secret generic host-keys-secret \
    --dry-run=client \
    --from-file=./temphostkeys/etc/ssh \
    -o yaml | \
    kubectl apply -f -

    exit 0

elif [ "$CMD" = "debug" ]
then
    start_munge --foreground

else
    exec "$@"
fi
