#!/bin/bash

# see https://github.com/yandex-cloud/geesefs

# //////////////////////////////////////////////////////////////////
function FuseUp() {
    echo "FuseUp geesefs..."
    sync && DropCache
    
    # memory limit is in MB
    geesefs \
        --cache ${CACHE_DIR} \
        --log-file ${LOG_DIR}/log.txt \
        --no-checksum \
        --max-flushers 32 \
        --max-parallel-parts 32 \
        --part-sizes 25 \
        --endpoint https://s3.${AWS_DEFAULT_REGION}.amazonaws.com \
        ${BUCKET_NAME} \
        ${TEST_DIR} || true # the command does not return 0 (weird)
    mount | grep ${TEST_DIR}
    echo "FuseUp  geesefs done"
}

# //////////////////////////////////////////////////////////////////
function FuseDown() {
    echo "FuseDown geesefs..."
    sync && DropCache
    Retry umount ${TEST_DIR}
    Retry rm -Rf ${BASE_DIR}
    echo "FuseDown geesefs done"
}
