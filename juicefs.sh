#!/bin/bash

source $(dirname $0)/utils.sh

echo "///////////////////////////////////////////////////////////////////////"
echo "WARNING the JuiceFs file system must have been created in juicefs      "
echo "WARNING the File system to create must have a name nsdf-test-juicefs   "
echo "WARNING see https://juicefs.com/console/create                         "
echo "WARNING the token must be set as environment variable                  "
echo "///////////////////////////////////////////////////////////////////////"

export JUICE_TOKEN=${JUICE_TOKEN:-XXXXX}

InitFuseBenchmark juicefs

# update the system
sudo apt update
sudo apt install -y nload fio expect python3 python3-pip fuse libfuse-dev awscli

# install juicefs
wget -q https://juicefs.com/static/juicefs
chmod +x juicefs 
sudo mv juicefs /usr/bin

juicefs auth \
    ${BUCKET_NAME} \
    --token ${JUICE_TOKEN} \
    --accesskey ${ACCESS_KEY} \
    --secretkey ${SECRET_ACCESS_KEY} 

# TODO: make sure juicefs is not using RAM cache
juicefs mount \
    ${BUCKET_NAME} \
    ${TEST_DIR} \
    --log=${LOG_DIR}/log.log \
    --max-uploads=150 \
    --cache-dir=${CACHE_DIR} \
    --cache-size=${DISK_CACHE_SIZE_MB}  

CheckFuseMount juicefs
RunDiskTest ${TEST_DIR}    
TerminateFuseBenchmark juicefs


