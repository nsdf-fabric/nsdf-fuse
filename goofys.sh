#!/bin/bash

# //////////////////////////////////////////////////////////////////
function FuseUp() {
    echo "FuseUp goofys..."
    sync && DropCache

    # Goofys does not have an on disk data cache (checkout catfs)
    goofys --region ${AWS_DEFAULT_REGION} ${BUCKET_NAME} ${TEST_DIR}
    mount | grep ${TEST_DIR}
    echo "FuseUp goofys done"
}

# //////////////////////////////////////////////////////////////////
function FuseDown() {
    echo "FuseDown goofys..."
    sync && DropCache
    Retry umount ${TEST_DIR}
    Retry rm -Rf ${BASE_DIR}
    echo "FuseDown goofys done"
}
