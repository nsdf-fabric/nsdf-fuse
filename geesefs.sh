#!/bin/bash
set -e # exit when any command fails
source ./fuse_test.sh

# /////////////////////////////////////////////////////////////////
function InstallGeeseFs() {
    if [[ ! -f /usr/bin/geesefs ]] ; then
        wget https://github.com/yandex-cloud/geesefs/releases/latest/download/geesefs-linux-amd64
        sudo mv geesefs-linux-amd64 /usr/bin/geesefs
        chmod a+x /usr/bin/geesefs
    fi
}

# /////////////////////////////////////////////////////////////////
function CreateCredentials() {
    # create a file with the credentials
    mkdir -p ${HOME}/.aws
cat << EOF > ${HOME}/.aws/credentials
[default]
aws_access_key_id=${AWS_ACCESS_KEY_ID}
aws_secret_access_key=${AWS_SECRET_ACCESS_KEY}
EOF
}

# /////////////////////////////////////////////////////////////////
function FuseUp() {
    # see https://github.com/yandex-cloud/geesefs
    # --debug_s3 --debug_fuse \
    geesefs \
        --cache ${CACHE_DIR} \
        --no-checksum \
        --memory-limit ${DISK_CACHE_SIZE_MB} \
        --max-flushers 32 \
        --max-parallel-parts 32 \
        --part-sizes 25 \
        --log-file ${LOG_DIR}/log.txt \
        --endpoint https://s3.${AWS_DEFAULT_REGION}.amazonaws.com \
        ${BUCKET_NAME} ${TEST_DIR}
    mount | grep ${TEST_DIR}
}

BUCKET_NAME=nsdf-fuse-geesefs
InitFuseBenchmark 
InstallGeeseFs
CreateBucket 
CreateCredentials
RunFuseTest 
RemoveBucket 
TerminateFuseBenchmark 
rm -f ${HOME}/.aws/credentials
