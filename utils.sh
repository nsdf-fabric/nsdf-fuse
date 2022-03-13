#!/bin/bash 

# ///////////////////////////////////////////////////////////
function InitFuseBenchmark() {

    NAME=$1

    echo "InitFuseBenchmark ${NAME}..."

    # update the system
    sudo apt -qq update
    sudo apt -qq install -y nload expect python3 python3-pip fuse libfuse-dev awscli

    # I need a recent version of fio
    if [[ ! -f ${HOME}/fio/fio_installed ]] ; then
        pushd ${HOME}
        git clone https://github.com/axboe/fio
        cd fio
        ./configure
        make 
        sudo make install
        sudo cp /usr/local/bin/fio /usr/bin/fio # overwite eventually existing one
        touch ./fio_installed
        popd 
    fi 

    # for boto3 aws-cli tools
    export BUCKET_NAME=nsdf-fuse-test-${NAME}

    # CACHE SIZE IN MB, make it small so that numbers are not affected too much by disk cache
    export DISK_CACHE_SIZE_MB=1024

    # CACHE SIZE IN MB, make it small so that numbers are not affected too much by disk cache
    export RAM_CACHE_SIZE_MB=1024

    # this will contain FUSE mount point, logs etc
    export BASE_DIR=${HOME}/mount/${BUCKET_NAME}
    export TEST_DIR=${BASE_DIR}/test
    export CACHE_DIR=${BASE_DIR}/cache
    export LOG_DIR=${BASE_DIR}/log

    echo "BUCKET_NAME:        ${BUCKET_NAME}"
    echo "BUCKET_REGION:      ${AWS_DEFAULT_REGION}"
    echo "DISK_CACHE_SIZE_MB: ${DISK_CACHE_SIZE_MB}"
    echo "RAM_CACHE_SIZE_MB:  ${RAM_CACHE_SIZE_MB}"
    echo "BASE_DIR:           ${BASE_DIR}"
    echo "TEST_DIR:           ${TEST_DIR}"
    echo "CACHE_DIR:          ${CACHE_DIR}"
    echo "LOG_DIR:            ${LOG_DIR}"

    # create and share the directory
    mkdir     -p ${BASE_DIR}  || true
    mkdir     -p ${TEST_DIR}  || true
    mkdir     -p ${CACHE_DIR} || true
    mkdir     -p ${LOG_DIR}   || true

    echo "InitFuseBenchmark ${NAME} done"
}

# ///////////////////////////////////////////////////////////
function FuseDown() {
    echo "FuseDown"
    # unmount but keeping the remote data
    umount ${TEST_DIR}    
    rm -Rf ${CACHE_DIR}/* 
    rm -Rf ${TEST_DIR}/*
    mount | grep ${TEST_DIR}
}


# ///////////////////////////////////////////////////////////
function SudoWriteOneLineFile() {
    sudo bash -c "echo $2 > $1"
}

