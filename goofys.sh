#!/bin/bash
set -e # exit when any command fails
source ./fuse_test.sh

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

    # create and share the directory
    mkdir     -p ${BASE_DIR}  || true
    mkdir     -p ${TEST_DIR}  || true
    mkdir     -p ${CACHE_DIR} || true
    mkdir     -p ${LOG_DIR}   || true

    # logs goes to syslog (==there is no way to redirect it?)
    goofys --region ${AWS_DEFAULT_REGION} ${BUCKET_NAME} ${TEST_DIR}
    mount | grep ${TEST_DIR}
}

# ///////////////////////////////////////////////////////////
function FuseDown() {
    echo "FuseDown..."
    CHECK TEST_DIR
    CHECK CACHE_DIR
    umount ${TEST_DIR} 
    rm -Rf ${BASE_DIR}
    echo "FuseDown done"
}

BUCKET_NAME=nsdf-fuse-goofys
InitFuseTest 
InstallGoofys
EnableCaching
CreateBucket 
RunFuseTest 
RemoveBucket 
TerminateFuseTest



