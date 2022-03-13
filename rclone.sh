#!/bin/bash
set -e # exit when any command fails
source ./fuse_test.sh

# /////////////////////////////////////////////////////////////////
function InstallRClone() {\
  if [[ ! -f ~/.rclone.installed ]] ; then
    wget https://downloads.rclone.org/v1.57.0/rclone-v1.57.0-linux-amd64.deb
    sudo dpkg -i rclone-v1.57.0-linux-amd64.deb
    rm rclone-v1.57.0-linux-amd64.deb
    touch ~/.rclone.installed
  fi
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

    # create and share the directory
    mkdir     -p ${BASE_DIR}  || true
    mkdir     -p ${TEST_DIR}  || true
    mkdir     -p ${CACHE_DIR} || true
    mkdir     -p ${LOG_DIR}   || true

  rclone mount my-rclone-config-item:${BUCKET_NAME} ${TEST_DIR} \
    --config ${RCLONE_CONFIG_FILE} \
    --vfs-cache-mode writes \
    --use-server-modtime \
    --cache-dir ${CACHE_DIR} \
    --vfs-cache-mode minimal \
    --uid $UID \
    --daemon
  mount | grep ${TEST_DIR}
  echo "rclone daemon started"
}


# ///////////////////////////////////////////////////////////
function FuseDown() {
    # override since i need sudo
    echo "FuseDown (objectivefs)..."
    CHECK TEST_DIR
    CHECK CACHE_DIR
    CHECK TEST_DIR
    sudo umount ${TEST_DIR}
    rm -Rf ${BASE_DIR}
    echo "FuseDown (objectivefs) done"
}

BUCKET_NAME=nsdf-fuse-rclone
RCLONE_CONFIG_FILE=$HOME/nsdf-test-rclone.conf
InitFuseTest 
InstallRClone
CreateCredentials
CreateBucket
RunFuseTest 
RemoveBucket
TerminateFuseTest
rm -f $RCLONE_CONFIG_FILE

