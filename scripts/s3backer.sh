#!/bin/bash

# Explanation:
#   Linux loop back mount
#   s3backer <---> remote S3 storage

# cons: I need to know the size in advance
#       here I am using a blocksize of 4M (network friendly)


# //////////////////////////////////////////////////////////////////////////
function Install_s3backer() {
	sudo apt install -y s3backer
	sudo sh -c 'echo user_allow_other >> /etc/fuse.conf'

	# check the version
	s3backer --version	
}

# //////////////////////////////////////////////////////////////////////////
function Uninstall_s3backer() {
	# nothing to do
	echo "nothing to do"
}

# //////////////////////////////////////////////////////////////////
function MountBackend() {
    echo "MountBackend  s3backer..."
    mkdir -p ${CACHE_DIR}/backend
	 OVERALL_SIZE=256G

	# disabling caching
   # --blockCacheFile=${CACHE_DIR}/block_cache_file
	# --blockCacheSize=???
   # --blockCacheThreads=64  
    Retry s3backer \
            --accessId=${AWS_ACCESS_KEY_ID} \
            --accessKey=${AWS_SECRET_ACCESS_KEY} \
            --region=${AWS_DEFAULT_REGION}  \
            --blockSize=4M \
            --size=$OVERALL_SIZE \
				--endpoint=${AWS_S3_ENDPOINT_URL} \
            ${BUCKET_NAME} ${CACHE_DIR}/backend
    CheckMount ${CACHE_DIR}/backend
    echo "MountBackend  s3backer done"
}


# //////////////////////////////////////////////////////////////////
function CreateBucket() {
    echo "CreateBucket  s3backer..."
    aws s3api create-bucket --bucket ${BUCKET_NAME} --region ${AWS_DEFAULT_REGION}
    MountBackend
    mkfs.ext4 \
        -E nodiscard \
        -F ${CACHE_DIR}/backend/file
    Retry umount ${CACHE_DIR}/backend
    echo "CreateBucket s3backer done"
}

# //////////////////////////////////////////////////////////////////
function FuseUp(){
    echo "FuseUp s3backer..."
    sync && DropCache
    Retry mkdir -p ${TEST_DIR}
    MountBackend
    sudo mount -o loop  -o discard ${CACHE_DIR}/backend/file ${TEST_DIR}  
	 CheckMount ${TEST_DIR}
    sudo chmod a+rwX -R ${TEST_DIR}
    echo "FuseUp s3backer done"
}

# //////////////////////////////////////////////////////////////////
function FuseDown() {
    echo "FuseDown s3backer..."
    sync && DropCache
    Retry sudo umount ${TEST_DIR}
    Retry umount ${CACHE_DIR}/backend
    Retry rm -Rf ${BASE_DIR}
    echo "FuseDown s3backer done"
}