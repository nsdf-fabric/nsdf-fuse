#!/bin/bash
set -e # exit when any command fails

source ./utils.sh
source ./disk.sh
InitFuseBenchmark objectivefs

OBJECTIVEFS_LICENSE=${OBJECTIVEFS_LICENSE:-XXXXX}

# install objectivefs
wget -q https://objectivefs.com/user/download/asn7gu3nd/objectivefs_6.9.1_amd64.deb
sudo dpkg -i objectivefs_6.9.1_amd64.deb

sudo mkdir -p /etc/objectivefs.env
SudoWriteOneLineFile /etc/objectivefs.env/OBJECTIVEFS_LICENSE     ${OBJECTIVEFS_LICENSE}
SudoWriteOneLineFile /etc/objectivefs.env/AWS_ACCESS_KEY_ID       ${AWS_ACCESS_KEY_ID}
SudoWriteOneLineFile /etc/objectivefs.env/AWS_SECRET_ACCESS_KEY   ${AWS_SECRET_ACCESS_KEY}
SudoWriteOneLineFile /etc/objectivefs.env/AWS_DEFAULT_REGION      ""
SudoWriteOneLineFile /etc/objectivefs.env/OBJECTIVEFS_LICENSE  ${OBJECTIVEFS_LICENSE}
sudo chmod ug+rwX,a-rwX -R /etc/objectivefs.env

sudo cat << EOF > ofs_create_bucket.sh
#!/usr/bin/expect -f
set timeout -1
spawn mount.objectivefs create -l ${BUCKET_REGION} ${BUCKET_NAME}
match_max 100000
expect -exact "for s3://${BUCKET_NAME}): "
send -- "${OBJECTIVEFS_LICENSE}\r"
expect -exact "for s3://${BUCKET_NAME}): "
send -- "${OBJECTIVEFS_LICENSE}\r"
expect eof
EOF

chmod a+x ofs_create_bucket.sh
sudo ofs_create_bucket.sh

# see https://objectivefs.com/howto/performance-amazon-efs-vs-objectivefs-large-files
# cannot change log location
sudo \
    DISKCACHE_SIZE=${DISK_CACHE_SIZE_MB}M \
    DISKCACHE_PATH=${CACHE_DIR} \
    CACHESIZE=${RAM_CACHE_SIZE_MB} \
    mount.objectivefs -o mt s3://${BUCKET_NAME} ${TEST_DIR}

CheckFuseMount objectivefs
RunDiskTest ${TEST_DIR}  
TerminateFuseBenchmark objectivefs

rm -f ofs_create_bucket.sh