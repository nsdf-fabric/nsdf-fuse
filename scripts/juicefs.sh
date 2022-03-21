#!/bin/bash

# IMPORTANT: internally the real bucket name will be juicefs-${BUCKET_NAME}



# //////////////////////////////////////////////////////////////////////////
function Install_juicefs() {
	echo "NOTE you need to create a File System named `juicefs-nsdf-fuse-test-juicefs` (see https://juicefs.com/console/)."
	wget -q https://juicefs.com/static/juicefs
	sudo mv juicefs /usr/bin
	chmod +x /usr/bin/juicefs

	# check the version
	juicefs version	
}

# //////////////////////////////////////////////////////////////////////////
function Uninstall_juicefs() {
	sudo rm -f /usr/bin/juicefs
}


# //////////////////////////////////////////////////////////////////
function CreateBucket() {
    echo "CreateBucket  juicefs..."
    juicefs auth \
        ${BUCKET_NAME} \
        --token ${JUICE_TOKEN} \
        --accesskey ${AWS_ACCESS_KEY_ID} \
        --secretkey ${AWS_SECRET_ACCESS_KEY}  
    echo "CreateBucket  juicefs done"
}

# //////////////////////////////////////////////////////////////////
function RemoveBucket() {
    # note: there is a prefix
	aws s3 rb s3://juicefs-${BUCKET_NAME} --force
}

# //////////////////////////////////////////////////////////////////
function FuseUp() {
    echo "FuseUp juiscefs ..."
    sync && DropCache
    mkdir -p ${TEST_DIR}
    juicefs mount \
        ${BUCKET_NAME} \
        ${TEST_DIR} \
        --cache-dir=${CACHE_DIR} \
        --log=${LOG_DIR}/log.log \
        --max-uploads=150 
    mount | grep ${TEST_DIR}
    echo "FuseUp juicefs done"
}

# //////////////////////////////////////////////////////////////////
function FuseDown() {
    echo "FuseDown juicefs..."
    sync && DropCache
    Retry umount ${TEST_DIR}
    Retry rm -Rf ${BASE_DIR}
    echo "FuseDown juicefs done"
}