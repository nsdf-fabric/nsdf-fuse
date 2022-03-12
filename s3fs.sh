#!/bin/bash
set -e # exit when any command fails

source ./utils.sh
source ./disk.sh
InitFuseBenchmark s3fs

# install s3fs
sudo apt install -y s3fs 

# automatic authorization
echo ${AWS_ACCESS_KEY_ID}:${AWS_SECRET_ACCESS_KEY} > ${HOME}/.s3fs
chmod 600 ${HOME}/.s3fs

# see http://manpages.ubuntu.com/manpages/bionic/man1/s3fs.1.html

# create the bucket if necessary
aws s3 mb s3://${BUCKET_NAME} --region ${AWS_DEFAULT_REGION} 

# see https://cloud.ibm.com/docs/cloud-object-storage?topic=cloud-object-storage-s3fs
# TODO: there is no way to limit disk cache?
# NOTE: -o kernel_cache (DONT' WANT RAM CACHE)
sudo s3fs \
    ${BUCKET_NAME} \
    ${TEST_DIR} \
    -o passwd_file=${HOME}/.s3fs \
    -o endpoint=${AWS_DEFAULT_REGION} \
    -o use_cache=${CACHE_DIR} \
    -o cipher_suites=AESGCM \
    -o max_background=1000 \
    -o max_stat_cache_size=100000 \
    -o multipart_size=52 \
    -o parallel_count=30 \
    -o multireq_max=30 \
    -o allow_other 

CheckFuseMount s3fs
RunDiskTest ${TEST_DIR}  
TerminateFuseBenchmark s3fs

rm -f ${HOME}/.s3fs