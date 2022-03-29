#!/bin/bash


# //////////////////////////////////////////////////////////////////////////
function Install_rclone() {
	wget https://downloads.rclone.org/v1.57.0/rclone-v1.57.0-linux-amd64.deb
	sudo dpkg -i rclone-v1.57.0-linux-amd64.deb
	rm rclone-v1.57.0-linux-amd64.deb

	mkdir -p ~/.config/rclone/
	cat << EOF >> ~/.config/rclone/rclone.conf
[nsdf-test-rclone]
type=s3
provider=Other
access_key_id=${AWS_ACCESS_KEY_ID}
secret_access_key=${AWS_SECRET_ACCESS_KEY}
region=${AWS_DEFAULT_REGION} 
endpoint=${AWS_S3_ENDPOINT_URL}
EOF
	chmod 600 ~/.config/rclone/rclone.conf

	# check the version
	rclone --version	
}

# //////////////////////////////////////////////////////////////////////////
function Uninstall_rclone() {
	rm -f ~/.config/rclone/rclone.conf
}

# //////////////////////////////////////////////////////////////////
function FuseUp() {
    echo "FuseUp rclone..."
    sync && DropCache
    mkdir -p ${TEST_DIR}

	# note: disabling the cache
	# Without the use of --vfs-cache-mode this can only write files sequentially, 
	# it can only seek when reading.
	# NOTE I wasn't able to control the max cache size by  --vfs-cache-max-size 
	#      so i lowered the total IO a activity


   #--uid $UID \
  #--daemon \
  #--vfs-cache-mode full \
  #--use-server-modtime \

    rclone mount \
        nsdf-test-rclone:${BUCKET_NAME} \
        ${TEST_DIR} \
		  --daemon \
        --cache-dir ${CACHE_DIR} 
    
    CheckMount ${TEST_DIR}
    echo "FuseUp rclone done"
}


# //////////////////////////////////////////////////////////////////
function FuseDown() {
    echo "FuseDown rclone..."
    sync && DropCache
    Retry umount ${TEST_DIR}
    Retry rm -Rf ${BASE_DIR}
    echo "FuseDown rclone done"
}