#!/bin/bash

# https://www.rath.org/s3ql-docs/man/mkfs.html
# https://www.rath.org/s3ql-docs/man/mount.html



# //////////////////////////////////////////////////////////////////////////
function Install_s3ql() {

	echo "NOTE fuse3 is not compatible with fuse, used by most of other software, so you will need to run this s3ql at the end**:"
	echo "After the test repristinate the normal fuse:"
	echo "  sudo apt remove  -y fuse3"
	echo "  sudo apt install -y fuse"

	sudo apt remove  -y fuse 
	sudo apt install -y sqlite3 libsqlite3-dev pkg-config libfuse3-dev fuse3

	sudo pip3 install --upgrade pip
	sudo pip3 install --upgrade pyfuse3 google-auth-oauthlib dugong apsw defusedxml trio

	wget https://github.com/s3ql/s3ql/releases/download/release-3.8.1/s3ql-3.8.1.tar.gz

	tar xzf s3ql-3.8.1.tar.gz
	pushd s3ql-3.8.1
	python3 setup.py build_ext --inplace
	sudo python3 setup.py install 
	popd
	sudo rm -Rf s3ql-3.8.1.tar.gz s3ql-3.8.1

	# create credentials
	mkdir -p ${HOME}/.s3ql/
	cat << EOF > ~/.s3ql/authinfo2
[s3-test]
storage-url: s3://${AWS_DEFAULT_REGION}/${BUCKET_NAME}
backend-login: ${AWS_ACCESS_KEY_ID}
backend-password: ${AWS_SECRET_ACCESS_KEY}
EOF
	chmod 600 ~/.s3ql/authinfo2

	# check the version
	mount.s3ql --version	
}

# //////////////////////////////////////////////////////////////////////////
function Uninstall_s3ql() {
	sudo apt remove  -y fuse3
	sudo apt install -y fuse
	rm -f ~/.s3ql/authinfo2
}



# //////////////////////////////////////////////////////////////////
function CreateBucket() {

    echo "CreateBucket s3ql..."
    aws s3api create-bucket --bucket ${BUCKET_NAME} --region ${AWS_DEFAULT_REGION}

    mkfs.s3ql \
        --cachedir ${CACHE_DIR} \
        --log ${LOG_DIR}/log \
        --plain \
        s3://${AWS_DEFAULT_REGION}/${BUCKET_NAME}
    echo "CreateBucket s3ql done"
}


# //////////////////////////////////////////////////////////////////
function RemoveBucket() {
    # note: there is a prefix
	aws s3 rb s3://${BUCKET_NAME} --force
}



# //////////////////////////////////////////////////////////////////
function FuseUp() {
    echo "FuseUp s3ql..."
    sync && DropCache
    mkdir -p ${TEST_DIR}

    # --cachesize <size> Cache size in KiB (default: autodetect).
    Retry mount.s3ql \
            --cachedir ${CACHE_DIR} \
            --log ${LOG_DIR}/log \
            s3://${AWS_DEFAULT_REGION}/${BUCKET_NAME} \
            ${TEST_DIR} 
    mount | grep ${TEST_DIR}
    echo "FuseUp s3ql done"
}

# //////////////////////////////////////////////////////////////////
function FuseDown() {
    echo "FuseDown s3ql..."
    sync && DropCache
    Retry umount.s3ql --log ${LOG_DIR}/log ${TEST_DIR}
    Retry rm -Rf ${BASE_DIR}
    echo "FuseDown s3ql done"
}
