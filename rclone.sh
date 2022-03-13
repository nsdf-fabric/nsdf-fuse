#!/bin/bash
set -e # exit when any command fails
source ./fuse_test.sh

# /////////////////////////////////////////////////////////////////
function InstallRClone() {
  sudo apt -qq install -y rclone
}

# /////////////////////////////////////////////////////////////////
function CreateCredentials() {
  cat << EOF > ${RCLONE_CONFIG_FILE}
[my-rclone-config-item]
type=s3
provider=Other
access_key_id=${AWS_ACCESS_KEY_ID}
secret_access_key=${AWS_SECRET_ACCESS_KEY}
region=${AWS_DEFAULT_REGION} 
endpoint=https://s3.${AWS_DEFAULT_REGION}.amazonaws.com
EOF
  chmod 600 ${RCLONE_CONFIG_FILE}
}

# /////////////////////////////////////////////////////////////////
function FuseUp() {
  rclone mount my-rclone-config-item:${BUCKET_NAME} ${TEST_DIR} \
    --config ${RCLONE_CONFIG_FILE} \
    --vfs-cache-mode writes \
    --use-server-modtime \
    --cache-dir ${CACHE_DIR} \
    --vfs-cache-mode minimal \
    --uid $UID \
    --daemon || true # returns a non zero value
  mount | grep ${TEST_DIR}
}

BUCKET_NAME=nsdf-fuse-rclone
RCLONE_CONFIG_FILE=$HOME/nsdf-test-rclone.conf
InitFuseBenchmark 
InstallRClone
CreateCredentials
CreateBucket
RunFuseTest 
RemoveBucket
TerminateFuseBenchmark
rm -f $RCLONE_CONFIG_FILE

