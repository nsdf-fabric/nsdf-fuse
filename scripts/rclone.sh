#!/bin/bash

# //////////////////////////////////////////////////////////////////
function FuseUp() {
    echo "FuseUp rclone..."
    sync && DropCache

    rclone mount \
        nsdf-test-rclone:${BUCKET_NAME} \
        ${TEST_DIR} \
        --uid $UID \
        --daemon \
        --vfs-cache-mode writes \
        --use-server-modtime \
        --cache-dir ${CACHE_DIR} 
    mount | grep ${TEST_DIR}
    echo "FuseUp rclone done"
}


# //////////////////////////////////////////////////////////////////
function FuseDown() {
    echo "FuseDown rclone..."
    sync && DropCache
    Retry umount ${TEST_DIR}
    Retry rm -Rf ${BASE_DIR}
    echo "FuseDown rclone done"
}