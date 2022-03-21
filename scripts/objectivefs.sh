#!/bin/bash


# //////////////////////////////////////////////////////////////////////////
function Install_objectivefs() {
	wget -q https://objectivefs.com/user/download/asn7gu3nd/objectivefs_6.9.1_amd64.deb
	sudo dpkg -i objectivefs_6.9.1_amd64.deb
	rm objectivefs_6.9.1_amd64.deb

	sudo mkdir -p /etc/objectivefs.env
	sudo rm -Rf /etc/objectivefs.env/*
	sudo bash -c "echo ${AWS_ACCESS_KEY_ID}      > /etc/objectivefs.env/AWS_ACCESS_KEY_ID"
	sudo bash -c "echo ${AWS_SECRET_ACCESS_KEY}  > /etc/objectivefs.env/AWS_SECRET_ACCESS_KEY"
	sudo bash -c "echo ${AWS_DEFAULT_REGION}     > /etc/objectivefs.env/AWS_DEFAULT_REGION"
	sudo bash -c "echo ${OBJECTIVEFS_LICENSE}    > /etc/objectivefs.env/OBJECTIVEFS_LICENSE"
	sudo bash -c "echo ${OBJECTIVEFS_LICENSE}    > /etc/objectivefs.env/OBJECTIVEFS_PASSPHRASE"
	sudo chmod 600 /etc/objectivefs.env/*

	# check the version
	mount.objectivefs help 
}

# //////////////////////////////////////////////////////////////////////////
function Uninstall_objectivefs() {
	sudo rm -f /etc/objectivefs.env/AWS_ACCESS_KEY_ID
	sudo rm -f /etc/objectivefs.env/AWS_SECRET_ACCESS_KEY
	sudo rm -f /etc/objectivefs.env/AWS_DEFAULT_REGION
	sudo rm -f /etc/objectivefs.env/OBJECTIVEFS_LICENSE
	sudo rm -f /etc/objectivefs.env/OBJECTIVEFS_PASSPHRASE
}


# //////////////////////////////////////////////////////////////////
# see https://objectivefs.com/howto/performance-amazon-efs-vs-objectivefs-large-files
function CreateBucket() {

    echo "CreateBucket  objectivefs..."

    cat << EOF > create_bucket.sh
#!/usr/bin/expect -f
set timeout -1
spawn mount.objectivefs create -l ${AWS_DEFAULT_REGION} ${BUCKET_NAME}
match_max 100000
expect -exact "for s3://${BUCKET_NAME}): "
send -- "${OBJECTIVEFS_LICENSE}\r"
expect eof
EOF
    chmod a+x create_bucket.sh
    sudo ./create_bucket.sh
    rm create_bucket.sh

    # problem of file owned by root, remove it
    FuseUp
    Retry sudo rm -f ${TEST_DIR}/README
    FuseDown

    echo "CreateBucket  objectivefs done"
}


# //////////////////////////////////////////////////////////////////
function RemoveBucket() {
    # note: there is a prefix
	aws s3 rb s3://${BUCKET_NAME} --force
}


# //////////////////////////////////////////////////////////////////
function FuseUp() {

    echo "FuseUp objectivefs..."
    sync && DropCache
    mkdir -p ${TEST_DIR}
    
    export  DISKCACHE_PATH=${CACHE_DIR}
    sudo mount.objectivefs \
        -o mt \
        s3://${BUCKET_NAME} \
        ${TEST_DIR}
    CheckMount
    sudo chmod a+rwX -R ${TEST_DIR}
    echo "FuseUp objectivefs done"
}

# //////////////////////////////////////////////////////////////////
function FuseDown() {
    # overrideing because I need sudo here
    echo "FuseDown objectivefs..."
    sync && DropCache
    Retry sudo umount ${TEST_DIR} 
    Retry sudo rm -Rf ${BASE_DIR}
    echo "FuseDown objectivefs done"
}