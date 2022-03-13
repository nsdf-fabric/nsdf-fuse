#!/bin/bash 

# ///////////////////////////////////////////////////////////
function InitFuseBenchmark() {

    echo "InitFuseBenchmark..."

    CHECK BUCKET_NAME
    
    CHECK AWS_ACCESS_KEY_ID
    CHECK AWS_SECRET_ACCESS_KEY
    CHECK AWS_DEFAULT_REGION

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

    # CACHE SIZE IN MB, make it small so that numbers are not affected too much by disk cache
    export DISK_CACHE_SIZE_MB=1024

    # CACHE SIZE IN MB, make it small so that numbers are not affected too much by disk cache
    export RAM_CACHE_SIZE_MB=1024

    # this will contain FUSE mount point, logs etc
    export BASE_DIR=${HOME}/mount/buckets/${BUCKET_NAME}

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

    echo "InitFuseBenchmark done"
}

# ///////////////////////////////////////////////////////////
function TerminateFuseBenchmark() {
    echo "TerminateFuseBenchmark..."
    CHECK BUCKET_NAME
    rm -Rf ${BASE_DIR}
    echo "TerminateFuseBenchmark done"
}


# ///////////////////////////////////////////////////////////
function FuseDown() {

    echo "FuseDown..."

    CHECK TEST_DIR
    CHECK CACHE_DIR
    CHECK TEST_DIR
    # unmount but keeping the remote data
    umount ${TEST_DIR}    
    rm -Rf ${CACHE_DIR}/* 
    rm -Rf ${TEST_DIR}/*

    echo "FuseDown done"
}

# ///////////////////////////////////////////////////////////
function CreateBucket() {
    echo "CreateBucker..."
    CHECK BUCKET_NAME
    CHECK AWS_ACCESS_KEY_ID
    CHECK AWS_SECRET_ACCESS_KEY
    CHECK AWS_DEFAULT_REGION
    aws s3 mb s3://${BUCKET_NAME} --region ${AWS_DEFAULT_REGION} 
    aws s3 ls 
    echo "CreateBucker done"
}

# ///////////////////////////////////////////////////////////
function RemoveBucket() {
    echo "RemoveBucket..."
    CHECK BUCKET_NAME
    # note it can take a while before I see the destruction
    aws s3 rb --force s3://${BUCKET_NAME}
    aws s3 ls 
    echo "RemoveBucket done"
}


# ///////////////////////////////////////////////////////////
function CHECK() { 
  if [[ "${!1}" == "" ]] ; then 
    echo "ERROR \$$1 is empty"
    # exit 1 
  fi
}

# ///////////////////////////////////////////////////////////////
function RunFioTest() {

    # some options are stolen from https://docs.weka.io/v/3.10/testing-and-troubleshooting/testing-weka-system-performance
    # Also: I am checking real network traffic by `sudo nload -u M -U M``

    echo "# ///////////////////////////////////////////////////////////"
    echo "Starting test [$1] TEST_DIR=${TEST_DIR}..." 
    FuseUp

    fio $@ \
        --directory=${TEST_DIR} \
        --filename_format='$jobnum/$filenum/test.$jobnum.$filenum.bin' \
        --ioengine=posixaio \
        --exitall_on_error=1 \
        --create_serialize=0 \
        --end_fsync=1 \
        --disk_util=0 \
        --group_reporting \
        --ramp_time=2s \
        --direct=1
    
    FuseDown
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
function CleanBucket() {
    echo "CleanBucket..."
    FuseUp 
    rm -Rf ${TEST_DIR}/* 
    FuseDown
    echo "CleanBucket done"
}

# /////////////////////////////////////////////////////
function RunFuseTest() {

    CHECK TEST_DIR
    
    echo "RunFuseTest TEST_DIR=${TEST_DIR}..."

    mkdir -p ${TEST_DIR}
    rm -Rf   ${TEST_DIR}/* 

    if [[ "${FAST}" != "" ]] ; then

         RunFioWriteTest --name=fast-test   --rw=write --bs=4M --filesize=32M --numjobs=1 --size=32M

    else

        # one sequential (tot-storage=filesize*numjobs=64G fuse-activity=size=64G)
        RunFioWriteTest --name=one-seq-write   --rw=write --bs=4M --filesize=64G --numjobs=1     --size=64G
        RunFioReadTest  --name=one-seq-read    --rw=read  --bs=4M --filesize=64G --numjobs=1     --size=64G
        CleanBucket

        # multi sequential (tot-storage=filesize*numjobs=64G fuse-activity=size=64G)
        RunFioWriteTest --name=multi-seq-write --rw=write --bs=4M  --filesize=1G  --numjobs=64   --size=64G
        RunFioReadTest  --name=multi-seq-read  --rw=read  --bs=4M  --filesize=1G  --numjobs=64   --size=64G
        CleanBucket

        # rand test (tot-storage=filesize*numjobs=64G fuse-activity=numjobs*size=8G) (WEIRD: rand test use --size with a different meaning)
        RunFioWriteTest --name=rand-write --rw=randwrite  --bs=64k  --filesize=2G --numjobs=32   --size=256M
        RunFioReadTest  --name=rand-read  --rw=randread   --bs=64k  --filesize=2G --numjobs=32   --size=256M
        CleanBucket

        # lot of writing small files (can take several minutes)
        echo "# ///////////////////////////////////////////////////////////"    
        echo "Start test [tar-xzf]..." 
        wget  https://curl.se/download/curl-7.82.0.tar.gz 
        FuseUp 
        time -p tar xzf curl-7.82.0.tar.gz 1>/dev/null -C ${TEST_DIR} 
        FuseDown
        echo "Test [tar-xzf] done"
        rm -f curl-7.82.0.tar.gz
        echo

        # lot of removal of small files
        echo "# ///////////////////////////////////////////////////////////"    
        echo "Start test [rm-file]..." 
        FuseUp 
        time -p rm -Rf ${TEST_DIR}/* 
        FuseDown
        echo "Test [rm-file] done." 
        echo

    fi

    CleanBucket

    echo "RunFuseTest TEST_DIR=${TEST_DIR} done"
}

