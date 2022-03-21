#!/bin/bash


# //////////////////////////////////////////////////////////////////////////
function Install_goofys() {
	wget https://github.com/kahing/goofys/releases/latest/download/goofys
	sudo mv goofys /usr/bin/
	chmod a+x /usr/bin/goofys

	# check the version
	goofys --version	
}

# //////////////////////////////////////////////////////////////////////////
function Uninstall_goofys() {
	sudo rm -f /usr/bin/goofys
	rm -f ${HOME}/.aws/credentials
}



# /////////////////////////////////////////////////////////////////
function CreateBucket()
{
	aws s3api create-bucket --bucket ${BUCKET_NAME} --region ${AWS_DEFAULT_REGION}
}

# //////////////////////////////////////////////////////////////////
function RemoveBucket() {
    # note: there is a prefix
	aws s3 rb s3://${BUCKET_NAME} --force
}


# //////////////////////////////////////////////////////////////////
function FuseUp() {
    echo "FuseUp goofys..."
    sync && DropCache
    mkdir -p ${TEST_DIR}

    # Goofys does not have an on disk data cache (checkout catfs)
    goofys --region ${AWS_DEFAULT_REGION} ${BUCKET_NAME} ${TEST_DIR}
    mount | grep ${TEST_DIR}
    echo "FuseUp goofys done"
}

# //////////////////////////////////////////////////////////////////
function FuseDown() {
    echo "FuseDown goofys..."
    sync && DropCache
    Retry umount ${TEST_DIR}
    Retry rm -Rf ${BASE_DIR}
    echo "FuseDown goofys done"
}
