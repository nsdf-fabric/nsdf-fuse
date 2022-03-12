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
    export AWS_ACCESS_KEY_ID=${ACCESS_KEY}
    export AWS_SECRET_ACCESS_KEY=${SECRET_ACCESS_KEY}
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
    echo "BUCKET_REGION:      ${BUCKET_REGION}"
    echo "DISK_CACHE_SIZE_MB: ${DISK_CACHE_SIZE_MB}"
    echo "RAM_CACHE_SIZE_MB:  ${RAM_CACHE_SIZE_MB}"
    echo "BASE_DIR:           ${BASE_DIR}"
    echo "TEST_DIR:           ${TEST_DIR}"
    echo "CACHE_DIR:          ${CACHE_DIR}"
    echo "LOG_DIR:            ${LOG_DIR}"

    # create and share the directory
    sudo mkdir     -p ${BASE_DIR}  || true
    sudo mkdir     -p ${TEST_DIR}  || true
    sudo mkdir     -p ${CACHE_DIR} || true
    sudo mkdir     -p ${LOG_DIR}   || true
    sudo chmod 777 -R ${BASE_DIR} 

    echo "InitFuseBenchmark ${NAME} done"
}


# ///////////////////////////////////////////////////////////
function CheckFuseMount() {

    NAME=$1

    echo "CheckFuseMount ${NAME}..."
    mount
    echo "hello" > ${TEST_DIR}/first_file
    aws s3api list-objects --bucket ${BUCKET_NAME} --region ${BUCKET_REGION}    

    
    echo "CheckFuseMount ${NAME} done"  
}


# ///////////////////////////////////////////////////////////
function TerminateFuseBenchmark() {

    NAME=$1

    echo "TerminateFuseBenchmark ${NAME}..."

    # by checking the disk utization I will be use the limit is satisfied
    echo "Please check the cache size, should not be more than ${CACHE_SIZE_MB}"
    du -hs ${CACHE_DIR}

    # just to be extra sure the data is removed from cloud
    # ths can fail
    sudo rm -Rf   ${TEST_DIR}/* || true
    sudo umount   ${TEST_DIR}
    sudo rm -Rf   ${BASE_DIR}

    # check there is no mount
    mount

    # destroy the bucket
    aws s3 rb --force s3://${BUCKET_NAME} 
    
    echo "TerminateFuseBenchmark ${NAME} done"  
}


# ///////////////////////////////////////////////////////////
function SudoWriteOneLineFile() {
    sudo bash -c "echo $2 > $1"
}

