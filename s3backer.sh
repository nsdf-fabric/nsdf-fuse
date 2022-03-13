#!/bin/bash
set -e # exit when any command fails
source ./fuse_test.sh

# /////////////////////////////////////////////////////////////////
function InstallS3Backer() {
    sudo apt install -y s3backer
    sudo sh -c 'echo user_allow_other >> /etc/fuse.conf'
}


# /////////////////////////////////////////////////////////////////
function FuseUp(){
    echo "FuseUp (s3backer)..."

    # Explanation:
    #   Linux loop back mount
    #   s3backer <---> remote S3 storage

    # do `s3backer --help`` for all options
    OVERALL_SIZE=1T                                                   # overall size, you should known in advance
    BLOCK_SIZE_MB=4                                                   # single block size
    NUM_BLOCK_TO_CACHE=$(( ${RAM_CACHE_SIZE_MB} / ${BLOCK_SIZE_MB} )) # number of blocks to cache
    NUM_THREADS=64                                                    # number of threads

    mkdir -p ${CACHE_DIR}/backend
    s3backer --accessId=${AWS_ACCESS_KEY_ID} \
             --accessKey=${AWS_SECRET_ACCESS_KEY} \
             --blockCacheFile=${CACHE_DIR}/block_cache_file \
             --blockSize=${BLOCK_SIZE_MB}M \
             --size=${OVERALL_SIZE} \
             --region=${AWS_DEFAULT_REGION} \
             --blockCacheSize=${NUM_BLOCK_TO_CACHE} \
             --blockCacheThreads=${NUM_THREADS} \
             ${BUCKET_NAME} \
             ${CACHE_DIR}/backend  

    mount | grep ${CACHE_DIR}

    if [[ ! -f ${BASE_DIR}/s3_backer_backend_formatted ]] ; then
        echo "Formatting s3 backend..."
        mkfs.ext4 -E nodiscard -F ${CACHE_DIR}/backend/file
        touch ${BASE_DIR}/s3_backer_backend_formatted
        echo "s3 backend formatted"
    fi

    # Controls whether ext4 should issue discard/TRIM commands to the underlying block device 
    sudo mount -o loop -o discard ${CACHE_DIR}/backend/file ${TEST_DIR}
    sudo mount | grep ${TEST_DIR}
    sudo chmod a+rwX ${TEST_DIR}

    echo "FuseUp (s3backer) done"
}

# /////////////////////////////////////////////////////////////////
function FuseDown() {
    # overriding since I need to umount two file system
    echo "FuseDown (s3backer)..."
    CHECK TEST_DIR
    CHECK CACHE_DIR
    sudo umount ${TEST_DIR}
    umount ${CACHE_DIR}/backend
    rm -Rf ${CACHE_DIR}/* 
    rm -Rf ${TEST_DIR}/*
    echo "FuseDown (s3backer) done"
}

BUCKET_NAME=nsdf-fuse-s3backer
InitFuseTest 
InstallS3Backer
CreateBucket
RunFuseTest  
RemoveBucket 
TerminateFuseTest 


