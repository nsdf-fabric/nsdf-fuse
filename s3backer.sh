#!/bin/bash

source $(dirname $0)/utils.sh
InitFuseBenchmark s3backer

# update the system
sudo apt update
sudo apt install -y nload fio expect python3 python3-pip fuse libfuse-dev awscli

# install s3 backer
sudo apt install -y s3backer
sudo sh -c 'echo user_allow_other >> /etc/fuse.conf'

# do `s3backer --help`` for all options
OVERALL_SIZE=1T                                                   # overall size, you should known in advance
BLOCK_CACHE_FILE=${BASE_DIR}/blocks                               # where to store block informations
BLOCK_SIZE_MB=4                                                   # single block size
NUM_BLOCK_TO_CACHE=$(( ${RAM_CACHE_SIZE_MB} / ${BLOCK_SIZE_MB} )) # number of blocks to cache
NUM_THREADS=32                                                    # number of threads

S3_BACKEND_DIR=${BASE_DIR}/s3_backend
mkdir -p ${S3_BACKEND_DIR}

# create the bucket if necessary
aws s3 mb s3://${BUCKET_NAME} --region ${BUCKET_REGION} 

# Explanation:
#   Linux loop back mount
#   s3backer <---> remote S3 storage
s3backer \
    --accessId=${AWS_ACCESS_KEY_ID} \
    --accessKey=${AWS_SECRET_ACCESS_KEY} \
    --blockCacheFile=${BLOCK_CACHE_FILE} \
    --blockSize=${BLOCK_SIZE_MB}M \
    --size=${OVERALL_SIZE} \
    --region=${BUCKET_REGION} \
    --blockCacheSize=${NUM_BLOCK_TO_CACHE} \
    --blockCacheThreads=${NUM_THREADS} \
    ${BUCKET_NAME} \
    ${S3_BACKEND_DIR}  

mkfs.ext4 -E nodiscard -F ${S3_BACKEND_DIR}/file
sudo mount -o loop -o discard ${S3_BACKEND_DIR}/file ${TEST_DIR}

CheckFuseMount s3backer
RunDiskTest ${TEST_DIR}  
TerminateFuseBenchmark s3backer