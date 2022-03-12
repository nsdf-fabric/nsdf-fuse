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
    sudo rm -Rf   ${TEST_DIR}/*
    sudo umount   ${TEST_DIR}
    rm -Rf        ${BASE_DIR}
    mount

    # destroy the bucket
    aws s3 rm s3://${BUCKET_NAME} --recursive  
    
    echo "TerminateFuseBenchmark ${NAME} done"  
}


# ///////////////////////////////////////////////////////////////
function RunFioTest() {

    # some options are stolen from https://docs.weka.io/v/3.10/testing-and-troubleshooting/testing-weka-system-performance
    # Also: I am checking real network traffic by `sudo nload -u M -U M``

    echo "Starting test [$1] TEST_DIR=${TEST_DIR}..." 
    set -x
    fio $@ \
        --directory=${TEST_DIR} \
        --filename_format='$jobnum/$filenum/test.$jobnum.$filenum.bin' \
        --ioengine=posixaio \
        --exitall_on_error=1 \
        --create_serialize=0 \
        --end_fsync=1 \
        --disk_util=0 \
        --direct=1 
    set +x
    echo "Test [$1] done"
    echo

    # minimize effect of RAM cache
    sudo sh -c "/usr/bin/echo 3 > /proc/sys/vm/drop_caches"
}

# /////////////////////////////////////////////////////
function RunFioWriteTest() {
    # I create the file with random data (refill_buffers)
    RunFioTest $@ --allow_file_create=1  --end_fsync=1 --refill_buffers --create_serialize=0 --fallocate=none
}

# /////////////////////////////////////////////////////
function RunFioReadTest() {
    # i reuse files from previous write, thus I don't allow file creation
    RunFioTest $@ --allow_file_create=0
}

# /////////////////////////////////////////////////////
function RunTarTest() {
    # lot of writing small files (can take several minutes)
    echo "Start test [tar-xzf]..." 
    wget  https://curl.se/download/curl-7.82.0.tar.gz 
    time tar xzf curl-7.82.0.tar.gz 1>/dev/null -C ${TEST_DIR}
    echo "Test [tar-xzf] done"
    echo

    # lot of removal of small files
    echo "Start test [rm-file]..." 
    time rm -Rf $TEST_DIR/* 
    echo "Test [rm-file] done." 
    echo
}

# /////////////////////////////////////////////////////
function RunDiskTest() {

    TEST_DIR=${1:-/tmp/run-disk-test}
    
    echo "RunDiskTest TEST_DIR=${TEST_DIR}..."

    mkdir -p ${TEST_DIR}
    rm -Rf   ${TEST_DIR}/* 

    # one sequential (tot-storage=filesize*numjobs=64G fuse-activity=size=64G)
    RunFioWriteTest --name=one-seq-write   --rw=write --bs=4M --filesize=64G --numjobs=1     --size=64G 
    RunFioReadTest  --name=one-seq-read    --rw=read  --bs=4M --filesize=64G --numjobs=1     --size=64G 
    rm -Rf $TEST_DIR/* 

    # multi sequential (tot-storage=filesize*numjobs=64G fuse-activity=size=64G)
    RunFioWriteTest --name=multi-seq-write --rw=write --bs=4M  --filesize=1G  --numjobs=64   --size=64G   
    RunFioReadTest  --name=multi-seq-read  --rw=read  --bs=4M  --filesize=1G  --numjobs=64   --size=64G
    rm -Rf $TEST_DIR/*

    # rand test (tot-storage=filesize*numjobs=64G fuse-activity=numjobs*size=8G) (WEIRD: rand test use --size with a different meaning)
    RunFioWriteTest --name=rand-write --rw=randwrite  --bs=64k  --filesize=2G --numjobs=32   --size=256M
    RunFioReadTest  --name=rand-read  --rw=randread   --bs=64k  --filesize=2G --numjobs=32   --size=256M 
    rm -Rf $TEST_DIR/* 

    # equivalent ?
    # sysbench fileio --file-total-size=64G --file-test-mode=seqwr --time=30 --max-requests=0 --threads 64 prepare  
    # sysbench fileio --file-total-size=64G --file-test-mode=seqwr --time=30 --max-requests=0 --threads 64 run  
    # sysbench fileio --file-total-size=64G --file-test-mode=seqwr --time=30 --max-requests=0 --threads 64 clean  

    RunTarTest

    echo "RunDiskTest TEST_DIR=${TEST_DIR} done"
}


# ///////////////////////////////////////////////////////////
function SudoWriteOneLineFile() {
    sudo bash -c "echo $2 > $1"
}

