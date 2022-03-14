#!/bin/bash
set -e # exit when any command fails
set -x

# example:
# test.sh geesefs create-bucket
SOFTWARE=$1
TEST_NAME=$2

# ///////////////////////////////////////////////////////////
function BaseCreateBucket() {
    echo "BaseCreateBucket name=$1 region=$2..."
    aws s3 mb s3://${1} --region ${2}
}

# ///////////////////////////////////////////////////////////
function BaseRemoveBucket() {
    echo "BaseRemoveBucket ${1}..."
    aws s3 rb --force s3://${1}
    echo "BaseRemoveBucket ${1} done"
}

# ///////////////////////////////////////////////////////////
function CreateBucket() {
    BaseCreateBucket ${BUCKET_NAME} ${AWS_DEFAULT_REGION}
}

# ///////////////////////////////////////////////////////////
function RemoveBucket() {
    BaseRemoveBucket ${BUCKET_NAME}
}

# ///////////////////////////////////////////////////////////
function FuseUp() {
    echo "ERROR FuseUp To override"
    exit 1
}

# ///////////////////////////////////////////////////////////
function FuseDown() {
    # first I unmount and then I remove all the cached (like I did a reboot)
    umount ${TEST_DIR} 
    rm -Rf ${BASE_DIR}
}

# ///////////////////////////////////////////////////////////////
# see https://docs.weka.io/v/3.10/testing-and-troubleshooting/testing-weka-system-performance
function RunFioTest() {
    fio $@ \
        --directory=${TEST_DIR} \
        --filename_format='$jobnum/$filenum/test.$jobnum.$filenum.bin' \
        --ioengine=posixaio \
        --exitall_on_error=1 \
        --create_serialize=0 \
        --end_fsync=1 \
        --disk_util=0 \
        --group_reporting \
        --ramp_time=2s \
        --direct=1
}


# ////////////////////////////////////////////////////////////////////////////////
# see https://github.com/yandex-cloud/geesefs
if [[  "${SOFTWARE}" == "geesefs" ]] ; then

    function FuseUp() {
        geesefs \
            --cache ${CACHE_DIR} \
            --memory-limit ${DISK_CACHE_SIZE_MB} \
            --log-file ${LOG_DIR}/log.txt \
            --no-checksum \
            --max-flushers 32 \
            --max-parallel-parts 32 \
            --part-sizes 25 \
            --endpoint https://s3.${AWS_DEFAULT_REGION}.amazonaws.com \
            ${BUCKET_NAME} \
            ${TEST_DIR} || true # the command does not return 0 (weird)
        mount | grep ${TEST_DIR}
    }
fi

# ////////////////////////////////////////////////////////////////////////////////
if [[  "${SOFTWARE}" == "goofys" ]] ; then

    function FuseUp() {
        goofys \
            --region ${AWS_DEFAULT_REGION} \
            ${BUCKET_NAME} \
            ${TEST_DIR}
        mount | grep ${TEST_DIR}
    }
fi

# ////////////////////////////////////////////////////////////////////////////////
# IMPORTANT: internally the real bucket name will be juicefs-${BUCKET_NAME}
if [[  "${SOFTWARE}" == "juicefs" ]] ; then

    function CreateBucket() {
        juicefs auth \
            ${BUCKET_NAME} \
            --token ${JUICE_TOKEN} \
            --accesskey ${AWS_ACCESS_KEY_ID} \
            --secretkey ${AWS_SECRET_ACCESS_KEY}  
    }

    function RemoveBucket() {
        # note: there is a prefix
        BaseRemoveBucket juicefs-${BUCKET_NAME}
    }

    function FuseUp() {
        juicefs mount \
            ${BUCKET_NAME} \
            ${TEST_DIR} \
            --cache-dir=${CACHE_DIR} \
            --log=${LOG_DIR}/log.log \
            --max-uploads=150 \
            --cache-size=${DISK_CACHE_SIZE_MB}
        mount | grep ${TEST_DIR}
    }
fi

# ////////////////////////////////////////////////////////////////////////////////
# see https://objectivefs.com/howto/performance-amazon-efs-vs-objectivefs-large-files
if [[  "${SOFTWARE}" == "objectivefs" ]] ; then

    function CreateBucket() {
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
        sudo rm ${TEST_DIR}/README
        FuseDown
    }

    function FuseUp() {
        export  DISKCACHE_SIZE=${DISK_CACHE_SIZE_MB}M
        export  DISKCACHE_PATH=${CACHE_DIR}
        export  CACHESIZE=${RAM_CACHE_SIZE_MB}
        sudo mount.objectivefs \
            -o mt \
            s3://${BUCKET_NAME} \
            ${TEST_DIR}
        sudo mount | grep ${TEST_DIR}
        sudo chmod a+rwX -R ${TEST_DIR}
    }

    # overrideing because I need sudo here
    function FuseDown() {
        sudo umount ${TEST_DIR} 
        rm -Rf ${BASE_DIR}
    }


fi

if [[  "${SOFTWARE}" == "rclone" ]] ; then
    function FuseUp() {
        rclone mount \
            nsdf-test-rclone:${BUCKET_NAME} \
            ${TEST_DIR} \
            --uid $UID \
            --daemon \
            --vfs-cache-mode writes \
            --use-server-modtime \
            --cache-dir ${CACHE_DIR} \
            --vfs-cache-mode minimal 
        mount | grep ${TEST_DIR}
    }
fi

# ////////////////////////////////////////////////////////////////////////////////
# Explanation:
#   Linux loop back mount
#   s3backer <---> remote S3 storage
if [[  "${SOFTWARE}" == "s3backer" ]] ; then

    function MountBackend() {
        mkdir -p ${CACHE_DIR}/backend
        for i in 1 2 3 4 5; do 
            s3backer \
                --accessId=${AWS_ACCESS_KEY_ID} \
                --accessKey=${AWS_SECRET_ACCESS_KEY} \
                --region=${AWS_DEFAULT_REGION}  \
                --blockCacheFile=${CACHE_DIR}/block_cache_file \
                --blockSize=4M \
                --size=1T \
                --blockCacheThreads=64  \
                --blockCacheSize=$(( ${RAM_CACHE_SIZE_MB} / 4 )) \
                ${BUCKET_NAME} ${CACHE_DIR}/backend  && break
            sleep 1
        done
        mount | grep ${CACHE_DIR}
    }

    function CreateBucket() {
        BaseCreateBucket ${BUCKET_NAME} ${AWS_DEFAULT_REGION}
        MountBackend
        mkfs.ext4 \
            -E nodiscard \
            -F ${CACHE_DIR}/backend/file
        umount ${CACHE_DIR}/backend
    }

    function FuseUp(){
        MountBackend
        sudo mount \
            -o loop \
            -o discard \
            ${CACHE_DIR}/backend/file \
            ${TEST_DIR}  
        mount | grep ${TEST_DIR}
        sudo chmod a+rwX -R ${TEST_DIR}
    }

    function FuseDown() {
        sudo umount ${TEST_DIR}
        umount ${CACHE_DIR}/backend
        rm -Rf ${BASE_DIR}
    }
fi

# ////////////////////////////////////////////////////////////////////////////////
# see http://manpages.ubuntu.com/manpages/bionic/man1/s3fs.1.html
# see https://cloud.ibm.com/docs/cloud-object-storage?topic=cloud-object-storage-s3fs
if [[  "${SOFTWARE}" == "s3fs" ]] ; then

    function FuseUp() {
        s3fs \
            ${BUCKET_NAME} \
            ${TEST_DIR} \
            -o passwd_file=${HOME}/.s3fs \
            -o endpoint=${AWS_DEFAULT_REGION} \
            -o use_cache=${CACHE_DIR} \
            -o cipher_suites=AESGCM \
            -o max_background=1000 \
            -o max_stat_cache_size=100000 \
            -o multipart_size=52 \
            -o parallel_count=30 \
            -o multireq_max=30 \
            -o allow_other  
        mount | grep ${TEST_DIR}
    }
fi

# ////////////////////////////////////////////////////////////////////////////////
# https://www.rath.org/s3ql-docs/man/mkfs.html
# https://www.rath.org/s3ql-docs/man/mount.html
if [[  "${SOFTWARE}" == "s3ql" ]] ; then

    function CreateBucket() {
        BaseCreateBucket ${BUCKET_NAME} ${AWS_DEFAULT_REGION}
        mkfs.s3ql \
            --cachedir ${CACHE_DIR} \
            --log ${LOG_DIR}/log \
            --plain \
            s3://${AWS_DEFAULT_REGION}/${BUCKET_NAME}
    }

    function FuseUp() {
        for i in 1 2 3 4 5; do 
            mount.s3ql \
                --cachedir ${CACHE_DIR} \
                --log ${LOG_DIR}/log \
                --cachesize $(( ${DISK_CACHE_SIZE_MB} * 1024 )) \
                s3://${AWS_DEFAULT_REGION}/${BUCKET_NAME} \
                ${TEST_DIR}  && break
            sleep 1
        done
        mount | grep ${TEST_DIR}
        echo "FuseUp (s3ql) done"
    }

    function FuseDown() {
        umount.s3ql --log ${LOG_DIR}/log ${TEST_DIR}
        rm -Rf ${BASE_DIR}
    }

fi

# ////////////////////////////////////////////////////////////////////////////////
# check traffic by `sudo nload -u M -U M`

BUCKET_NAME=nsdf-fuse-test-${SOFTWARE}

export BASE_DIR=${HOME}/temp-mount/temp-buckets/${BUCKET_NAME}
export TEST_DIR=${BASE_DIR}/test
export CACHE_DIR=${BASE_DIR}/cache
export LOG_DIR=${BASE_DIR}/log
export DISK_CACHE_SIZE_MB=1024 # CACHE SIZE IN MB, make it small so that numbers are not affected too much by disk cache
export RAM_CACHE_SIZE_MB=1024 # CACHE SIZE IN MB, make it small so that numbers are not affected too much by disk cache

echo "BUCKET_NAME:        ${BUCKET_NAME}"
echo "AWS_DEFAULT_REGION: ${AWS_DEFAULT_REGION}"
echo "DISK_CACHE_SIZE_MB: ${DISK_CACHE_SIZE_MB}"
echo "RAM_CACHE_SIZE_MB:  ${RAM_CACHE_SIZE_MB}"
echo "BASE_DIR:           ${BASE_DIR}"
echo "TEST_DIR:           ${TEST_DIR}"
echo "CACHE_DIR:          ${CACHE_DIR}"
echo "LOG_DIR:            ${LOG_DIR}"

echo "Starting TEST_NAME=${TEST_NAME} TEST_DIR=${TEST_DIR}..." 

# minimize effect of RAM cache
sudo sh -c "/usr/bin/echo 3 > /proc/sys/vm/drop_caches" 

mkdir  -p ${BASE_DIR}  || true
mkdir  -p ${TEST_DIR}  || true
mkdir  -p ${CACHE_DIR} || true
mkdir  -p ${LOG_DIR}   || true

if [[ "${TEST_NAME}" == "create-bucket" ]] ; then
    CreateBucket
    aws s3 ls  

elif [[ "${TEST_NAME}" == "remove-bucket" ]] ; then
    RemoveBucket 
    aws s3 ls     

elif [[ "${TEST_NAME}" == "clean-bucket" ]] ; then
    SECONDS=0
    FuseUp
    time -p rm -Rf ${TEST_DIR}/* 
    FuseDown
    echo "${TEST_NAME} done. Seconds: $SECONDS"

elif [[ "${TEST_NAME}" == "create-clean-remove-bucket" ]] ; then
    ./test.sh $SOFTWARE create
    ./test.sh $SOFTWARE clean
    ./test.sh $SOFTWARE remove

elif [[ "${TEST_NAME}" == "clean-all" ]] ; then
    # !!! dangerous !!!
    
    # remove mounts
    for it in $(mount | grep temp-mount/temp-buckets | cut -d" " -f3); do 
        sudo umount $it  || true
    done

    # remove buckets
    for it in $(aws s3 ls | cut -d" " -f3); do 
        aws s3 rb s3://$it --force || true
    done

    rm -Rf ~/temp-mount/temp-buckets  || true

elif [[ "${TEST_NAME}" == "fuse-up" ]] ; then
    FuseUp 

elif [[ "${TEST_NAME}" == "fuse-down" ]] ; then
    FuseDown 

else

    OPTION_W="--allow_file_create=1  --end_fsync=1 --refill_buffers --create_serialize=0 --fallocate=none"
    OPTION_R="--allow_file_create=0"

    # tot_storage=filesize*numjobs=64G fuse-activity=size=64G
    if [[ "${TEST_NAME}" == "seq-1-write" ]] ; then
        SECONDS=0
        FuseUp
        RunFioTest --name=seq-1-write --rw=write --bs=4M --filesize=64G --numjobs=1  --size=64G ${OPTION_W} || true
        FuseDown
        echo "${TEST_NAME} done. Seconds: $SECONDS"

    elif [[ "${TEST_NAME}" == "seq-1-read" ]] ; then
        SECONDS=0
        FuseUp
        RunFioTest  --name=seq-1-read --rw=read  --bs=4M --filesize=64G --numjobs=1 --size=64G ${OPTION_R} || true
        FuseDown
        echo "${TEST_NAME} done. Seconds: $SECONDS"

    # multi sequential (tot-storage=filesize*numjobs=64G fuse-activity=size=64G)
    elif [[ "${TEST_NAME}" == "seq-n-write" ]] ; then
        SECONDS=0
        FuseUp
        RunFioTest --name=seq-n-write --rw=write --bs=4M  --filesize=1G  --numjobs=64   --size=64G ${OPTION_W} || true
        FuseDown
        echo "${TEST_NAME} done. Seconds: $SECONDS"

    elif [[ "${TEST_NAME}" == "seq-n-read" ]] ; then
        SECONDS=0
        FuseUp
        RunFioTest  --name=seq-n-read  --rw=read  --bs=4M  --filesize=1G  --numjobs=64   --size=64G ${OPTION_R}  || true
        FuseDown
        echo "${TEST_NAME} done. Seconds: $SECONDS"

    # rand test (tot-storage=filesize*numjobs=64G fuse-activity=numjobs*size=8G) (WEIRD: rand test use --size with a different meaning)
    elif [[ "${TEST_NAME}" == "rnd-n-write" ]] ; then
        SECONDS=0
        FuseUp
        RunFioWriteTest --name=rnd-n-write --rw=randwrite  --bs=64k  --filesize=2G --numjobs=32   --size=256M ${OPTION_W} || true
        FuseDown
        echo "${TEST_NAME} done. Seconds: $SECONDS" 

    elif [[ "${TEST_NAME}" == "rnd-n-read" ]] ; then
        SECONDS=0
        FuseUp
        RunFioTest  --name=rnd-n-read  --rw=randread   --bs=64k  --filesize=2G --numjobs=32   --size=256M ${OPTION_R}  || true
        FuseDown
        echo "${TEST_NAME} done. Seconds: $SECONDS"

    elif [[ "${TEST_NAME}" == "tar-gz" ]] ; then
        wget  https://curl.se/download/curl-7.82.0.tar.gz 
        SECONDS=0
        FuseUp
        time -p tar xzf curl-7.82.0.tar.gz 1>/dev/null -C ${TEST_DIR} 
        FuseDown
        echo "${TEST_NAME} done. Seconds: $SECONDS"
        rm -f curl-7.82.0.tar.gz

    else
        echo "UNKNOWN TEST"
        exit 1
    fi
fi

echo "${TEST_NAME} done"
