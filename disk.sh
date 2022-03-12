#!/bin/bash 

# ///////////////////////////////////////////////////////////////
function RunFioTest() {

    # some options are stolen from https://docs.weka.io/v/3.10/testing-and-troubleshooting/testing-weka-system-performance
    # Also: I am checking real network traffic by `sudo nload -u M -U M``

    echo "# ///////////////////////////////////////////////////////////"
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
        --direct=1 || true # i have spurious error so I am ignoring errors here
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
    echo "# ///////////////////////////////////////////////////////////"    
    echo "Start test [tar-xzf]..." 
    wget  https://curl.se/download/curl-7.82.0.tar.gz 
    time tar xzf curl-7.82.0.tar.gz 1>/dev/null -C ${TEST_DIR}
    echo "Test [tar-xzf] done"
    echo

    # lot of removal of small files
    echo "# ///////////////////////////////////////////////////////////"    
    echo "Start test [rm-file]..." 
    time rm -Rf $TEST_DIR/* 
    echo "Test [rm-file] done." 
    echo

    rm -f curl-7.82.0.tar.gz
}

# /////////////////////////////////////////////////////
function RunDiskTest() {

    TEST_DIR=${1:-/tmp/run-disk-test}
    
    echo "RunDiskTest TEST_DIR=${TEST_DIR}..."

    mkdir -p ${TEST_DIR}
    rm -Rf   ${TEST_DIR}/* 

    if [[ "${FAST}" == "1" ]] ; then

        RunFioWriteTest --name=one-seq-write   --rw=write --bs=4M --filesize=64M --numjobs=1 --size=64M     
        rm -Rf $TEST_DIR/*  
        
    else

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

        RunTarTest
        m -Rf $TEST_DIR/* 

    fi

    echo "RunDiskTest TEST_DIR=${TEST_DIR} done"
}

