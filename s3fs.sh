#!/bin/bash
set -e # exit when any command fails
source ./fuse_test.sh

# /////////////////////////////////////////////////////////////////
function InstallS3Fs() {
    sudo apt install -y s3fs 
}

# /////////////////////////////////////////////////////////////////
function CreateCredentials() {
    echo ${AWS_ACCESS_KEY_ID}:${AWS_SECRET_ACCESS_KEY} > ${HOME}/.s3fs
    chmod 600 ${HOME}/.s3fs
}

# /////////////////////////////////////////////////////////////////
function FuseUp() {

    echo "FuseUp (s3fs)..."

    # create and share the directory
    mkdir     -p ${BASE_DIR}  || true
    mkdir     -p ${TEST_DIR}  || true
    mkdir     -p ${CACHE_DIR} || true
    mkdir     -p ${LOG_DIR}   || true

    # see http://manpages.ubuntu.com/manpages/bionic/man1/s3fs.1.html
    # see https://cloud.ibm.com/docs/cloud-object-storage?topic=cloud-object-storage-s3fs
    # TODO: there is no way to limit disk cache?
    # NOTE: -o kernel_cache (DONT' WANT RAM CACHE)
    s3fs \
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
    mount | grep ${TEST_DIR}  

    echo "FuseUp (s3fs) done"    
}


# ///////////////////////////////////////////////////////////
function FuseDown() {
    echo "FuseDown (s3fs)..."
    CHECK TEST_DIR
    CHECK CACHE_DIR
    CHECK TEST_DIR
    umount ${TEST_DIR}
    rm -Rf ${BASE_DIR}
    echo "FuseDown (s3fs) done"
}

BUCKET_NAME=nsdf-fuse-s3fs
InstallS3Fs
CreateCredentials
CreateBucket
RunFuseTest 
RemoveBucket 
TerminateFuseTest
rm -f ${HOME}/.s3fs
