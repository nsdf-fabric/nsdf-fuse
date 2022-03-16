#!/bin/bash

# //////////////////////////////////////////////////////////////////
# see https://objectivefs.com/howto/performance-amazon-efs-vs-objectivefs-large-files
function CreateBucket() {

    echo "CreateBucket  objectivefs..."

    cat << EOF > create_bucket.sh
#!/usr/bin/expect -f
set timeout -1
spawn mount.objectivefs create -l ${AWS_DEFAULT_REGION} ${BUCKET_NAME}
match_max 100000
expect -exact "for s3://${BUCKET_NAME}): "
send -- "${OBJECTIVEFS_LICENSE}\r"
expect eof
EOF
    chmod a+x create_bucket.sh
    sudo ./create_bucket.sh
    rm create_bucket.sh

    # problem of file owned by root, remove it
    FuseUp
    SudoRetry rm ${TEST_DIR}/README
    FuseDown

    echo "CreateBucket  objectivefs done"
}

# //////////////////////////////////////////////////////////////////
function FuseUp() {

    echo "FuseUp objectivefs..."
    sync && DropCache
    
    export  DISKCACHE_PATH=${CACHE_DIR}
    sudo mount.objectivefs \
        -o mt \
        s3://${BUCKET_NAME} \
        ${TEST_DIR}
    sudo mount | grep ${TEST_DIR}
    sudo chmod a+rwX -R ${TEST_DIR}

    echo "FuseUp objectivefs don"
}

# //////////////////////////////////////////////////////////////////
function FuseDown() {
    # overrideing because I need sudo here
    echo "FuseDown objectivefs..."
    sync && DropCache
    SudoRetry umount ${TEST_DIR} 
    SudoRetry rm -Rf ${BASE_DIR}
    echo "FuseDown objectivefs done"
}