#!/bin/bash

# IMPORTANT: internally the real bucket name will be juicefs-${BUCKET_NAME}

# //////////////////////////////////////////////////////////////////
function CreateBucket() {
    echo "CreateBucket  juicefs..."
    juicefs auth \
        ${BUCKET_NAME} \
        --token ${JUICE_TOKEN} \
        --accesskey ${AWS_ACCESS_KEY_ID} \
        --secretkey ${AWS_SECRET_ACCESS_KEY}  
    echo "CreateBucket  juicefs done"
}

# //////////////////////////////////////////////////////////////////
function RemoveBucket() {
    # note: there is a prefix
    BaseRemoveBucket juicefs-${BUCKET_NAME}
}

# //////////////////////////////////////////////////////////////////
function FuseUp() {
    echo "FuseUp juiscefs ..."
    sync && DropCache
    juicefs mount \
        ${BUCKET_NAME} \
        ${TEST_DIR} \
        --cache-dir=${CACHE_DIR} \
        --log=${LOG_DIR}/log.log \
        --max-uploads=150 
    mount | grep ${TEST_DIR}
    echo "FuseUp juicefs done"
}

# //////////////////////////////////////////////////////////////////
function FuseDown() {
    echo "FuseDown juicefs..."
    sync && DropCache
    Retry umount ${TEST_DIR}
    Retry rm -Rf ${BASE_DIR}
    echo "FuseDown juicefs done"
}