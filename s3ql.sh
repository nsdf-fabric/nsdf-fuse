#!/bin/bash
set -e # exit when any command fails
source ./fuse_test.sh

# /////////////////////////////////////////////////////////////////
function InstallS3QL() {

    export DEBIAN_FRONTEND=noninteractive 
    sudo apt install -y sqlite3 libsqlite3-dev pkg-config fuse3 libfuse3-dev
    sudo pip3 install --upgrade pip
    sudo pip3 install --upgrade pyfuse3 google-auth-oauthlib dugong apsw defusedxml trio

    # https://www.brightbox.com/docs/guides/s3ql/
    if [[ ! -f /usr/local/bin/s3qlstat ]] ; then
        wget https://github.com/s3ql/s3ql/releases/download/release-3.8.1/s3ql-3.8.1.tar.gz
        tar xzf s3ql-3.8.1.tar.gz
        pushd s3ql-3.8.1
        python3 setup.py build_ext --inplace
        sudo python3 setup.py install 
        popd
        sudo rm -Rf s3ql-3.8.1.tar.gz s3ql-3.8.1
    fi
}

# /////////////////////////////////////////////////////////////////
function CreateCredentials() {
    mkdir -p ${HOME}/.s3ql/

cat << EOF > ~/.s3ql/authinfo2
[s3]
storage-url: s3://${BUCKET_NAME}
backend-login: ${AWS_ACCESS_KEY_ID}
backend-password: ${AWS_SECRET_ACCESS_KEY}
EOF
    chmod 600 ~/.s3ql/authinfo2
}

# /////////////////////////////////////////////////////////////////
function FormatBucket() {

    echo "FormatBucket (s3ql)..."

    # create and share the directory
    mkdir     -p ${BASE_DIR}  || true
    mkdir     -p ${TEST_DIR}  || true
    mkdir     -p ${CACHE_DIR} || true
    mkdir     -p ${LOG_DIR}   || true   

    # create the bucket
    # https://www.rath.org/s3ql-docs/man/mkfs.html
    mkfs.s3ql \
        s3://${AWS_DEFAULT_REGION}/${BUCKET_NAME} \
        --cachedir ${CACHE_DIR} \
        --log ${LOG_DIR}/log 

    echo "FormatBucket (done)..."
}

# /////////////////////////////////////////////////////////////////
function FuseUp() {

    echo "FuseUp (s3ql)..."

    # create and share the directory
    mkdir     -p ${BASE_DIR}  || true
    mkdir     -p ${TEST_DIR}  || true
    mkdir     -p ${CACHE_DIR} || true
    mkdir     -p ${LOG_DIR}   || true    

    # mount it
    # https://www.rath.org/s3ql-docs/man/mount.html
    # TODO: disable RAM cache
    mount.s3ql \
        s3://${AWS_DEFAULT_REGION}/${BUCKET_NAME} \
        ${TEST_DIR} \
        --cachedir ${CACHE_DIR} \
        --log ${LOG_DIR}/log \
        --cachesize $(( ${DISK_CACHE_SIZE_MB} * 1024 ))

    mount | grep ${TEST_DIR}

    echo "FuseUp (s3ql) done"
}

# ///////////////////////////////////////////////////////////
function FuseDown() {
    # override since i need sudo
    echo "FuseDown (s3ql)..."
    sudo umount ${TEST_DIR}
    rm -Rf ${BASE_DIR}
    echo "FuseDown (s3ql) done"
}

# problem, cannot run in non-interactive since it asks for a password
BUCKET_NAME=nsdf-fuse-s3ql
InitFuseTest
InstallS3QL
CreateCredentials
CreateBucket 
FormatBucket
RunFuseTest 
RemoveBucket 
TerminateFuseTest
rm -f ${HOME}/.s3ql/authinfo2

