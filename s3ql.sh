#!/bin/bash

source ./utils.sh
InitFuseBenchmark s3ql

# https://www.brightbox.com/docs/guides/s3ql/
wget https://github.com/s3ql/s3ql/releases/download/release-3.8.1/
tar xzf s3ql-3.8.1.tar.gz
cd s3ql-3.8.1
sudo apt install -y 
sudo apt install -y sqlite3 libsqlite3-dev pkg-config fuse3 libfuse3-dev

sudo pip3 install --upgrade pip
sudo pip3 install pyfuse3 google-auth-oauthlib
sudo pip3 install --upgrade trio

python3 setup.py build_ext --inplace
sudo python3 setup.py install 

mkdir -p ${HOME}/.s3ql/
cat << EOF > ${HOME}/.s3ql/authinfo2
[default]
backend-login: ${ACCESS_KEY}
backend-password: ${SECRET_ACCESS_KEY}
EOF
chmod 600 ${HOME}/.s3ql/authinfo2

# create the bucket if necessary
aws s3 mb s3://${BUCKET_NAME} --region ${BUCKET_REGION} 

# create the bucket
# https://www.rath.org/s3ql-docs/man/mkfs.html
sudo mkfs.s3ql  \
    --cachedir ${CACHE_DIR} \
    --log ${LOG_DIR}/log \
    --authfile ${HOME}/.s3ql/authinfo2 \
    --plain \
    s3://${BUCKET_REGION}/${BUCKET_NAME}

# mount it
# https://www.rath.org/s3ql-docs/man/mount.html
# TODO: disable RAM cache
sudo mount.s3ql s3://${BUCKET_REGION}/${BUCKET_NAME} ${TEST_DIR} \
    --cachedir ${CACHE_DIR} \
    --log ${LOG_DIR}/log \
    --authfile ${HOME}/.s3ql/authinfo2 \
    --cachesize $(( ${DISK_CACHE_SIZE_MB} * 1024 )) \
    --allow-other

CheckFuseMount s3ql
RunDiskTest ${TEST_DIR}  
TerminateFuseBenchmark s3ql

rm -f ${HOME}/.s3ql/authinfo2

