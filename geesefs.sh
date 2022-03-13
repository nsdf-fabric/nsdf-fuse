#!/bin/bash
set -e # exit when any command fails
source ./fuse_test.sh

# /////////////////////////////////////////////////////////////////
function InstallGeeseFs() {
    if [[ ! -f ${HOME}/bin/geesefs ]] ; then
        wget https://github.com/yandex-cloud/geesefs/releases/latest/download/geesefs-linux-amd64
        mkdir -p $HOME/bin
        mv geesefs-linux-amd64 ${HOME}/bin/geesefs
        chmod a+x ${HOME}/bin/geesefs
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

    # create and share the directory
    mkdir     -p ${BASE_DIR}  || true
    mkdir     -p ${TEST_DIR}  || true
    mkdir     -p ${CACHE_DIR} || true
    mkdir     -p ${LOG_DIR}   || true

    # see https://github.com/yandex-cloud/geesefs
    # --debug_s3 --debug_fuse \
    ${HOME}/bin/geesefs \
        --cache ${CACHE_DIR} \
        --no-checksum \
        --memory-limit ${DISK_CACHE_SIZE_MB} \
        --max-flushers 32 \
        --max-parallel-parts 32 \
        --part-sizes 25 \
        --log-file ${LOG_DIR}/log.txt \
        --endpoint https://s3.${AWS_DEFAULT_REGION}.amazonaws.com \
        ${BUCKET_NAME} ${TEST_DIR} || true # the command does not return 0 (weird)
    echo "Check the following line is showing the mount"
    mount | grep ${TEST_DIR}
}

# ///////////////////////////////////////////////////////////
function FuseDown() {
    echo "FuseDown..."
    CHECK TEST_DIR
    CHECK CACHE_DIR
    umount ${TEST_DIR} 
    rm -Rf ${BASE_DIR}
    echo "FuseDown done"
}

BUCKET_NAME=nsdf-fuse-geesefs
InitFuseTest 
InstallGeeseFs
CreateBucket 
CreateCredentials
RunFuseTest 
RemoveBucket 
TerminateFuseTest 
rm -f ${HOME}/.aws/credentials
