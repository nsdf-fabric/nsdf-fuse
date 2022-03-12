#!/bin/bash
set -e # exit when any command fails

source ./utils.sh
source ./disk.sh
InitFuseBenchmark goofys

# install goofys
if [[ ! -f /usr/bin/goofys ]] ; then
    wget https://github.com/kahing/goofys/releases/latest/download/goofys
    chmod a+x goofys
    sudo mv goofys /usr/bin/
fi

# if you want to enable disk caching
# since I am having problems installing it I am just disabling
if [[ "0" == "1" ]] ; then
    sudo apt install -y cargo
    cargo install catfs
    sudo mv /home/ubuntu/.cargo/bin/catfs /usr/bin/
    # OPTION would be --cache "--free:${DISK_CACHE_SIZE_MB}M:${CACHE_DIR}" 
fi

# create the bucket if necessary
aws s3 mb s3://${BUCKET_NAME} --region ${BUCKET_REGION} 

# logs goes to syslog (==there is no way to redirect it?)
goofys \
    --region ${BUCKET_REGION} \
    ${BUCKET_NAME} \
    ${TEST_DIR}

CheckFuseMount goofys
RunDiskTest ${TEST_DIR}  
TerminateFuseBenchmark goofys
