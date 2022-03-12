#!/bin/bash
set -e # exit when any command fails

source ./utils.sh
InitFuseBenchmark geesefs

# install geesefs
if [[ ! -f /usr/bin/geesefs ]] ; then
    wget https://github.com/yandex-cloud/geesefs/releases/latest/download/geesefs-linux-amd64
    sudo mv geesefs-linux-amd64 /usr/bin/geesefs
    chmod a+x /usr/bin/geesefs
fi

# create the bucket if necessary
aws s3 mb s3://${BUCKET_NAME} --region ${BUCKET_REGION} 

# create a file with the credentials
mkdir -p ${HOME}/.aws
cat << EOF > ${HOME}/.aws/credentials
[default]
aws_access_key_id=${AWS_ACCESS_KEY_ID}
aws_secret_access_key=${AWS_SECRET_ACCESS_KEY}
EOF

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
    --endpoint https://s3.${BUCKET_REGION}.amazonaws.com \
    ${BUCKET_NAME} ${TEST_DIR} 

CheckFuseMount geesefs
RunDiskTest ${TEST_DIR}  
TerminateFuseBenchmark geesefs

# remove credentials
rm -f ${HOME}/.aws/credentials