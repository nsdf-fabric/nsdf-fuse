#!/bin/bash
set -e # exit when any command fails
source ./fuse_test.sh

# /////////////////////////////////////////////////////////////////
function InstallObjectiveFs() {
    wget -q https://objectivefs.com/user/download/asn7gu3nd/objectivefs_6.9.1_amd64.deb
    sudo dpkg -i objectivefs_6.9.1_amd64.deb
}

# /////////////////////////////////////////////////////////////////
function CreateCredentials() {
    sudo mkdir -p /etc/objectivefs.env
    sudo rm -Rf /etc/objectivefs.env/*
    sudo bash -c "echo ${AWS_ACCESS_KEY_ID}      > /etc/objectivefs.env/AWS_ACCESS_KEY_ID"
    sudo bash -c "echo ${AWS_SECRET_ACCESS_KEY}  > /etc/objectivefs.env/AWS_SECRET_ACCESS_KEY"
    sudo bash -c "echo ${AWS_DEFAULT_REGION}     > /etc/objectivefs.env/AWS_DEFAULT_REGION"
    sudo bash -c "echo ${OBJECTIVEFS_LICENSE}    > /etc/objectivefs.env/OBJECTIVEFS_LICENSE"
    sudo bash -c "echo ${OBJECTIVEFS_PASSPHRASE} > /etc/objectivefs.env/OBJECTIVEFS_PASSPHRASE"
    sudo chmod 600 /etc/objectivefs.env/*
}

# /////////////////////////////////////////////////////////////////
function CreateBucket() {
    cat << EOF > create_bucket.sh
#!/usr/bin/expect -f
set timeout -1
spawn mount.objectivefs create -l ${AWS_DEFAULT_REGION} ${BUCKET_NAME}
match_max 100000
expect -exact "for s3://${BUCKET_NAME}): "
send -- "${OBJECTIVEFS_PASSPHRASE}\r"
expect eof
EOF

    sudo chmod 700 create_bucket.sh
    sudo ./create_bucket.sh
    rm create_bucket.sh
    sudo chmod a+rwX -R ${TEST_DIR}
}

# /////////////////////////////////////////////////////////////////
function FuseUp() {
    # see https://objectivefs.com/howto/performance-amazon-efs-vs-objectivefs-large-files
    # cannot change log location ?
    export  DISKCACHE_SIZE=${DISK_CACHE_SIZE_MB}M
    export  DISKCACHE_PATH=${CACHE_DIR}
    export  CACHESIZE=${RAM_CACHE_SIZE_MB}
    sudo mount.objectivefs \
        -o mt \
        s3://${BUCKET_NAME} \
        ${TEST_DIR}
    sudo mount | grep ${TEST_DIR}
    sudo chmod a+rwX -R ${TEST_DIR}
}

# ///////////////////////////////////////////////////////////
function FuseDown() {
    # override since i need sudo
    echo "FuseDown (objectivefs)..."
    CHECK TEST_DIR
    CHECK CACHE_DIR
    CHECK TEST_DIR
    sudo umount ${TEST_DIR}
    sudo rm -Rf ${CACHE_DIR}/* 
    sudo rm -Rf ${TEST_DIR}/*
    echo "FuseDown (objectivefs) done"
}

# /////////////////////////////////////////////////////
function CleanBucket() {
    echo "CleanBucket (objectivefs)..."
    FuseUp 
    sudo rm -Rf ${TEST_DIR}/* || true # override because I need to use sudo
    FuseDown
    echo "CleanBucket (objectivefs) done"
}

BUCKET_NAME=nsdf-fuse-objectivefs
CHECK OBJECTIVEFS_LICENSE
OBJECTIVEFS_PASSPHRASE=${OBJECTIVEFS_LICENSE}
InitFuseBenchmark 
InstallObjectiveFs
CreateCredentials
CreateBucket 
RunFuseTest
RemoveBucket
TerminateFuseBenchmark 
sudo rm -Rf /etc/objectivefs.env/*
