#!/bin/bash

# Explanation:
#   Linux loop back mount
#   s3backer <---> remote S3 storage

# cons: I need to know the size in advance
#       here I am using a blocksize of 4M (network friendly)

# //////////////////////////////////////////////////////////////////
function MountBackend() {
    echo "MountBackend  s3backer..."
    mkdir -p ${CACHE_DIR}/backend
    Retry s3backer \
            --accessId=${AWS_ACCESS_KEY_ID} \
            --accessKey=${AWS_SECRET_ACCESS_KEY} \
            --region=${AWS_DEFAULT_REGION}  \
            --blockCacheFile=${CACHE_DIR}/block_cache_file \
            --blockSize=4M \
            --size=1T \
            --blockCacheThreads=64  \
            ${BUCKET_NAME} ${CACHE_DIR}/backend
    mount | grep ${CACHE_DIR}
    echo "MountBackend  s3backer done"
}

# //////////////////////////////////////////////////////////////////
function CreateBucket() {
    echo "CreateBucket  s3backer..."
    BaseCreateBucket ${BUCKET_NAME} ${AWS_DEFAULT_REGION}
    MountBackend
    mkfs.ext4 \
        -E nodiscard \
        -F ${CACHE_DIR}/backend/file
    Retry umount ${CACHE_DIR}/backend
    echo "CreateBucket s3backer done"
}

# //////////////////////////////////////////////////////////////////
function FuseUp(){
    echo "FuseUp s3backer..."
    sync && DropCache
    MountBackend
    sudo mount \
        -o loop \
        -o discard \
        ${CACHE_DIR}/backend/file \
        ${TEST_DIR}  
    mount | grep ${TEST_DIR}
    sudo chmod a+rwX -R ${TEST_DIR}
    echo "FuseUp s3backer done"
}

# //////////////////////////////////////////////////////////////////
function FuseDown() {
    echo "FuseDown s3backer..."
    sync && DropCache
    SudoRetry umount ${TEST_DIR}
    Retry umount ${CACHE_DIR}/backend
    Retry rm -Rf ${BASE_DIR}
    echo "FuseDown s3backer done"
}