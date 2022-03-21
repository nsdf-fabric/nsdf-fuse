#!/bin/bash

# see https://github.com/yandex-cloud/geesefs


# //////////////////////////////////////////////////////////////////////////
function Install_geesefs() {
	wget https://github.com/yandex-cloud/geesefs/releases/latest/download/geesefs-linux-amd64
	sudo mv geesefs-linux-amd64 /usr/bin/geesefs
	chmod a+x /usr/bin/geesefs

	mkdir -p ${HOME}/.aws
	cat << EOF > ${HOME}/.aws/credentials
[default]
aws_access_key_id=${AWS_ACCESS_KEY_ID}
aws_secret_access_key=${AWS_SECRET_ACCESS_KEY}
EOF

	# check the version
	geesefs --version
}

# //////////////////////////////////////////////////////////////////////////
function Uninstall_geesefs() {
	sudo rm -f /usr/bin/geesefs
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
    echo "FuseUp geesefs..."
    sync && DropCache
    mkdir -p ${TEST_DIR}
    # memory limit is in MB
    geesefs \
        --cache ${CACHE_DIR} \
        --no-checksum \
        --max-flushers 32 \
        --max-parallel-parts 32 \
        --part-sizes 25 \
        --endpoint https://s3.${AWS_DEFAULT_REGION}.amazonaws.com \
        ${BUCKET_NAME} \
        ${TEST_DIR}
    CheckMount
    echo "FuseUp geesefs done"
}

# //////////////////////////////////////////////////////////////////
function FuseDown() {
    echo "FuseDown geesefs..."
    sync && DropCache
    Retry umount ${TEST_DIR}
    Retry rm -Rf ${BASE_DIR}
    echo "FuseDown geesefs done"
}
