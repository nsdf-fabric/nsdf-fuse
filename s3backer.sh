#!/bin/bash
set -e # exit when any command fails
source ./fuse_test.sh

# /////////////////////////////////////////////////////////////////
function InstallS3Backer() {
    sudo apt install -y s3backer
    sudo sh -c 'echo user_allow_other >> /etc/fuse.conf'
}

# /////////////////////////////////////////////////////////////////
function CreateBackend() 
{
    # Explanation:
    #   Linux loop back mount
    #   s3backer <---> remote S3 storage

    # do `s3backer --help`` for all options
    OVERALL_SIZE=1T                                                   # overall size, you should known in advance
    BLOCK_SIZE_MB=4                                                   # single block size
    NUM_BLOCK_TO_CACHE=$(( ${RAM_CACHE_SIZE_MB} / ${BLOCK_SIZE_MB} )) # number of blocks to cache
    NUM_THREADS=64          
                                              # number of threads
    # where to cache/store block informations
    BLOCK_CACHE_FILE=${CACHE_DIR}/blocks   

    # directory that sync with S3 (note: it's a virtual directory)
    S3_BACKEND_DIR=${CACHE_DIR}/backend_dir

    mkdir -p ${S3_BACKEND_DIR}

    s3backer --accessId=${AWS_ACCESS_KEY_ID} \
             --accessKey=${AWS_SECRET_ACCESS_KEY} \
             --blockCacheFile=${BLOCK_CACHE_FILE} \
             --blockSize=${BLOCK_SIZE_MB}M \
             --size=${OVERALL_SIZE} \
             --region=${AWS_DEFAULT_REGION} \
             --blockCacheSize=${NUM_BLOCK_TO_CACHE} \
             --blockCacheThreads=${NUM_THREADS} \
             -o default_permissions,allow_other \
             -o uid=$UID \
             ${BUCKET_NAME} \
             ${S3_BACKEND_DIR}  

    # create the virtual file system
    mkfs.ext4 -E nodiscard -F ${S3_BACKEND_DIR}/file

}
# /////////////////////////////////////////////////////////////////
function FuseUp(){
    mount \
        -o loop \
        -o discard \
        -o default_permissions,allow_other \
        -o uid=$UID \
        ${S3_BACKEND_DIR}/file \
        ${TEST_DIR}
    mount | grep ${TEST_DIR}
}

BUCKET_NAME=nsdf-fuse-s3backer
InitFuseBenchmark 
CreateBucket
CreateBackend
RunFuseTest  
RemoveBucket 
TerminateFuseBenchmark 


