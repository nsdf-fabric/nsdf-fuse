#!/bin/bash
set -e # exit when any command fails
source ./fuse_test.sh

CHECK OBJECTIVEFS_LICENSE

# /////////////////////////////////////////////////////////////////
function InstallObjectiveFs() {
    wget -q https://objectivefs.com/user/download/asn7gu3nd/objectivefs_6.9.1_amd64.deb
    sudo dpkg -i objectivefs_6.9.1_amd64.deb
}

# /////////////////////////////////////////////////////////////////
function CreateCredentials() {
    sudo mkdir -p /etc/objectivefs.env
    sudo bash -c "echo ${OBJECTIVEFS_LICENSE}   > /etc/objectivefs.env/OBJECTIVEFS_LICENSE     "
    sudo bash -c "echo ${AWS_ACCESS_KEY_ID}     > /etc/objectivefs.env/AWS_ACCESS_KEY_ID "
    sudo bash -c "echo ${AWS_SECRET_ACCESS_KEY} > /etc/objectivefs.env/AWS_SECRET_ACCESS_KEY"
    sudo bash -c "echo ''                       > /etc/objectivefs.env/AWS_DEFAULT_REGION"
    sudo bash -c "echo ${OBJECTIVEFS_LICENSE}   > /etc/objectivefs.env/OBJECTIVEFS_LICENSE  "
    sudo chmod ug+rwX,a-rwX -R /etc/objectivefs.env
}

# /////////////////////////////////////////////////////////////////
function CreateBucket() {
    cat << EOF > ~/ofs_create_bucket.sh
#!/usr/bin/expect -f
set timeout -1
spawn mount.objectivefs create -l ${AWS_DEFAULT_REGION} ${BUCKET_NAME}
match_max 100000
expect -exact "for s3://${BUCKET_NAME}): "
send -- "${OBJECTIVEFS_LICENSE}\r"
expect -exact "for s3://${BUCKET_NAME}): "
send -- "${OBJECTIVEFS_LICENSE}\r"
expect eof
EOF
    chmod a+x ~/ofs_create_bucket.sh
    sudo ~/ofs_create_bucket.sh
}

# /////////////////////////////////////////////////////////////////
function FuseUp() {

    # see https://objectivefs.com/howto/performance-amazon-efs-vs-objectivefs-large-files
    # cannot change log location
    export  DISKCACHE_SIZE=${DISK_CACHE_SIZE_MB}M
    export  DISKCACHE_PATH=${CACHE_DIR}
    export  CACHESIZE=${RAM_CACHE_SIZE_MB}

    sudo mount.objectivefs -o mt s3://${BUCKET_NAME} ${TEST_DIR}
    sudo mount | grep ${TEST_DIR}
    sudo chmod 777 -R ${BASE_DIR} 
}

BUCKET_NAME=nsdf-fuse-objectivefs
InitFuseBenchmark 
InstallObjectiveFs
CreateCredentials
CreateBucket 
RunFuseTest
RemoveBucket
TerminateFuseBenchmark 
rm -f /tmp/ofs_create_bucket.sh
