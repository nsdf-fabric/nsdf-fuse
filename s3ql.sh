#!/bin/bash
set -e # exit when any command fails
source ./fuse_test.sh

# /////////////////////////////////////////////////////////////////
function InstallS3QL() {
    sudo apt install -y sqlite3 libsqlite3-dev pkg-config fuse3 libfuse3-dev
    sudo pip3 install --upgrade pip
    sudo pip3 install pyfuse3 google-auth-oauthlib dugong apsw defusedxml
    sudo pip3 install --upgrade trio

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
cat << EOF > ${HOME}/.s3ql/authinfo2
[default]
backend-login: ${AWS_ACCESS_KEY_ID}
backend-password: ${AWS_SECRET_ACCESS_KEY}
EOF
    chmod 600 ${HOME}/.s3ql/authinfo2
}

# /////////////////////////////////////////////////////////////////
function FuseUp() {

    # create the bucket
    # https://www.rath.org/s3ql-docs/man/mkfs.html
    mkfs.s3ql  \
        --cachedir ${CACHE_DIR} \
        --log ${LOG_DIR}/log \
        --authfile ${HOME}/.s3ql/authinfo2 \
        --plain \
        s3://${AWS_DEFAULT_REGION}/${BUCKET_NAME}

    # mount it
    # https://www.rath.org/s3ql-docs/man/mount.html
    # TODO: disable RAM cache
    mount.s3ql s3://${AWS_DEFAULT_REGION}/${BUCKET_NAME} ${TEST_DIR} \
        --cachedir ${CACHE_DIR} \
        --log ${LOG_DIR}/log \
        --authfile ${HOME}/.s3ql/authinfo2 \
        --cachesize $(( ${DISK_CACHE_SIZE_MB} * 1024 ))
    mount | grep ${TEST_DIR}
}

InitFuseBenchmark s3ql
InstallS3QL
CreateCredentials
CreateBucket ${BUCKET_NAME}
RunFuseTest ${TEST_DIR}  
RemoveBucket ${BUCKET_NAME} 
TerminateFuseBenchmark s3ql
rm -f ${HOME}/.s3ql/authinfo2

