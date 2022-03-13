#!/bin/bash
set -e # exit when any command fails
source ./fuse_test.sh
NAME=$(basename "$0" .sh)

# /////////////////////////////////////////////////////////////////
function InstallGoofys() {
    if [[ ! -f /usr/bin/goofys ]] ; then
        wget https://github.com/kahing/goofys/releases/latest/download/goofys
        chmod a+x goofys
        sudo mv goofys /usr/bin/
    fi
}

# /////////////////////////////////////////////////////////////////
function EnableCaching() {
    # if you want to enable disk caching
    # since I am having problems installing it I am just disabling
    if [[ "0" == "1" ]] ; then
        sudo apt install -y cargo
        cargo install catfs
        sudo mv /home/ubuntu/.cargo/bin/catfs /usr/bin/
        # OPTION would be --cache "--free:${DISK_CACHE_SIZE_MB}M:${CACHE_DIR}" 
    fi
}

# /////////////////////////////////////////////////////////////////
function FuseUp() {
    # logs goes to syslog (==there is no way to redirect it?)
    goofys --region ${AWS_DEFAULT_REGION} ${BUCKET_NAME} ${TEST_DIR}
    mount | grep ${TEST_DIR}
}

InitFuseBenchmark ${NAME}
InstallGoofys
EnableCaching
CreateBucket ${BUCKET_NAME}
RunFuseTest ${TEST_DIR}  
RemoveBucket ${BUCKET_NAME} 
TerminatTerminateFuseBenchmarkeFuseBencmark ${NAME}

