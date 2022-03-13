#!/bin/bash
set -e # exit when any command fails
source ./fuse_test.sh

# /////////////////////////////////////////////////////////////////
function InstallRClone() {
  sudo apt -qq install -y rclone
}

# /////////////////////////////////////////////////////////////////
function CreateCredentials() {
  # configuration file
  cat << EOF > ./rclone.conf
[rclone-s3]
type=s3
provider=Other
access_key_id=${AWS_ACCESS_KEY_ID}
secret_access_key=${AWS_SECRET_ACCESS_KEY}
region=${AWS_DEFAULT_REGION} 
endpoint=https://s3.${AWS_DEFAULT_REGION}.amazonaws.com
EOF
  chmod 600 ./rclone.conf
}

# /////////////////////////////////////////////////////////////////
function FuseUp() {
  rclone mount \
    rclone-s3:${BUCKET_NAME} \
    ${TEST_DIR} \
    --config ./rclone.conf \
    --vfs-cache-mode writes \
    --use-server-modtime \
    --cache-dir ${CACHE_DIR} \
    --vfs-cache-mode minimal \
    --daemon
  mount | grep ${TEST_DIR}
}


InitFuseBenchmark rclone-test
InstallRClone
CreateCredentials
CreateBucket ${BUCKET_NAME}
RunFuseTest ${TEST_DIR}    
RemoveBucket ${BUCKET_NAME} 
TerminateFuseBenchmark  rclone-test
rm -f ./rclone.conf

