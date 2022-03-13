#!/bin/bash
set -e # exit when any command fails

source ./utils.sh
source ./disk.sh
InitFuseBenchmark rclone

# install rclone
sudo apt -qq install -y rclone

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

# create the bucket if necessary
aws s3 mb s3://${BUCKET_NAME} --region ${AWS_DEFAULT_REGION} 


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

RunDiskTest ${TEST_DIR}    

aws s3 rb --force s3://${BUCKET_NAME}  
rm -Rf ${BASE_DIR}

rm -f ./rclone.conf

