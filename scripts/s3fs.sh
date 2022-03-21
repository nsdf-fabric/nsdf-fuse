#!/bin/bash

# see http://manpages.ubuntu.com/manpages/bionic/man1/s3fs.1.html
# see https://cloud.ibm.com/docs/cloud-object-storage?topic=cloud-object-storage-s3fs


# //////////////////////////////////////////////////////////////////////////
# NOTE: install from scratch, old version is buggy
function Install_s3fs() {
	sudo apt-get install -y autotools-dev automake libcurl4-openssl-dev libxml2-dev libssl-dev libfuse-dev fuse pkg-config
	git clone https://github.com/s3fs-fuse/s3fs-fuse.git
	pushd s3fs-fuse
	./autogen.sh
	./configure
	make
	sudo make install
	sudo mv /usr/local/bin/s3fs /usr/bin/
	echo ${AWS_ACCESS_KEY_ID}:${AWS_SECRET_ACCESS_KEY} > ${HOME}/.s3fs
	chmod 600 ${HOME}/.s3fs
	popd
	rm -Rf s3fs-fuse

	# check the version
	s3fs --version
}

# //////////////////////////////////////////////////////////////////////////
function Uninstall_s3fs() {
	sudo rm -f /usr/bin/s3fs
	rm -f ${HOME}/.s3fs
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
    echo "FuseUp s3fs..."
    sync && DropCache
    mkdir -p ${TEST_DIR}

    # disablng caching
    s3fs ${BUCKET_NAME} ${TEST_DIR} \
        -o passwd_file=${HOME}/.s3fs \
        -o endpoint=${AWS_DEFAULT_REGION} \
        -o use_cache="" \
        -o cipher_suites=AESGCM \
        -o max_background=1000 \
        -o max_stat_cache_size=100000 \
        -o multipart_size=52 \
        -o parallel_count=30 \
        -o multireq_max=30 \
        -o allow_other \
        -d
    
    mount | grep ${TEST_DIR}
    echo "FuseUp s3fs done"
}


# //////////////////////////////////////////////////////////////////
function FuseDown() {
    echo "FuseDown s3fs..."
    sync && DropCache
    Retry umount ${TEST_DIR}
    Retry rm -Rf ${BASE_DIR}
    echo "FuseDown s3fs done"
}