#!/bin/bash

# https://www.rath.org/s3ql-docs/man/mkfs.html
# https://www.rath.org/s3ql-docs/man/mount.html

# //////////////////////////////////////////////////////////////////
function CreateBucket() {

    echo "CreateBucket s3ql..."
    BaseCreateBucket ${BUCKET_NAME} ${AWS_DEFAULT_REGION}

    
    mkfs.s3ql \
        --cachedir ${CACHE_DIR} \
        --log ${LOG_DIR}/log \
        --plain \
        s3://${AWS_DEFAULT_REGION}/${BUCKET_NAME}
    echo "CreateBucket s3ql done"
}


# //////////////////////////////////////////////////////////////////
function FuseUp() {
    echo "FuseUp s3ql..."
    sync && DropCache

    # --cachesize <size> Cache size in KiB (default: autodetect).
    Retry mount.s3ql \
            --cachedir ${CACHE_DIR} \
            --log ${LOG_DIR}/log \
            s3://${AWS_DEFAULT_REGION}/${BUCKET_NAME} \
            ${TEST_DIR} 
    mount | grep ${TEST_DIR}
    echo "FuseUp s3ql done"
}

function FuseDown() {
    echo "FuseDown s3ql..."
    sync && DropCache
    Retry umount.s3ql --log ${LOG_DIR}/log ${TEST_DIR}
    Retry rm -Rf ${BASE_DIR}
    echo "FuseDown s3ql done"
}
