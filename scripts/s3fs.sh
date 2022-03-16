#!/bin/bash

# see http://manpages.ubuntu.com/manpages/bionic/man1/s3fs.1.html
# see https://cloud.ibm.com/docs/cloud-object-storage?topic=cloud-object-storage-s3fs

# //////////////////////////////////////////////////////////////////
function FuseUp() {
    echo "FuseUp s3fs..."
    sync && DropCache

    # disablng caching
    s3fs ${BUCKET_NAME} ${TEST_DIR} \
        -o passwd_file=${HOME}/.s3fs \
        -o endpoint=${AWS_DEFAULT_REGION} \
        -o use_cache="" \
        -o cipher_suites=AESGCM \
        -o max_background=1000 \
        -o max_stat_cache_size=100000 \
        -o multipart_size=52 \
        -o parallel_count=30 \
        -o multireq_max=30 \
        -o allow_other \
        -d
    
    mount | grep ${TEST_DIR}
    echo "FuseUp s3fs done"
}


# //////////////////////////////////////////////////////////////////
function FuseDown() {
    echo "FuseDown s3fs..."
    sync && DropCache
    Retry umount ${TEST_DIR}
    Retry rm -Rf ${BASE_DIR}
    echo "FuseDown s3fs done"
}