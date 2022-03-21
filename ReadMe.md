

# Setup

Define the credentials for the the tests (change as needed):

```

export AWS_ACCESS_KEY_ID=XXXXX
export AWS_SECRET_ACCESS_KEY=YYYYY
export AWS_DEFAULT_REGION_REGION=us-east-1

# # this is needed for ObjectiveFS tests
export OBJECTIVEFS_LICENSE=ZZZZZ 

# this is needed for JuiceFs tests
# you must create a "File System" (see https://juicefs.com/console/)
# with name `nsdf-fuse-test-juicefs`
export JUICE_TOKEN=KKKKK
```

Clone this repository and install all dependencies:

```
git clone https://github.com/nsdf-fabric/nsdf-fuse-test
cd nsdf-fuse-test
export PATH=$PWD:$PATH
```


# Tests

```
# Once only: install all dependencies to run tests
nsdf-fuse update-os
nsdf-fuse install-fio

# DANGEROUS (!!!), please carefully read  the code before executing
# It forces a full cleaning (==destro) of all buckets, mounts, files, caches etc
# lot of paths are hardcoded
nsdf-fuse clean-all

# set up the target what do you want to use
TARGET=juicefs

# create test bucket
nsdf-fuse $TARGET create-bucket

# mount the test bucket
nsdf-fuse $TARGET up

# create a test file file
nsdf-fuse $TARGET touch

# find all files inside the bucket
nsdf-fuse $TARGET find

# unmount the object storage filesystem. it removes all the caches
# it's like rebooting the computer to loose any cache and repeat the tests
nsdf-fuse $TARGET down

# totally destroy the bucket, to run only when the file system it's not going to be used in the future
# (or for testing)
nsdf-fuse $TARGET remove-bucket

```

# Quick tests

```
nsdf-fuse update-os
nsdf-fuse install-fio

nsdf-fuse geesefs     install create-bucket up touch down clean-bucket remove-bucket 
nsdf-fuse goofys      install create-bucket up touch down clean-bucket remove-bucket 
nsdf-fuse juicefs     install create-bucket up touch down clean-bucket remove-bucket 
nsdf-fuse objectivefs install create-bucket up touch down clean-bucket remove-bucket 
nsdf-fuse rclone      install create-bucket up touch down clean-bucket remove-bucket 
nsdf-fuse s3backer    install create-bucket up touch down clean-bucket remove-bucket 
nsdf-fuse s3fs        install create-bucket up touch down clean-bucket remove-bucket 
nsdf-fuse s3ql        install create-bucket up touch down clean-bucket remove-bucket uninstall
```

# Benchmarks

Example:

```
TARGET=juicefs
nsdf-fuse $TARGET fio-benchmark seq-1-read
nsdf-fuse $TARGET fio-benchmark seq-1-write
nsdf-fuse $TARGET fio-benchmark seq-n-read
nsdf-fuse $TARGET fio-benchmark seq-n-write
nsdf-fuse $TARGET fio-benchmark rand-1-read
nsdf-fuse $TARGET fio-benchmark rand-1-write

nsdf-fuse $TARGET simple-benchmark seq-1-write
nsdf-fuse $TARGET simple-benchmark seq-1-read
nsdf-fuse $TARGET clean-bucket 

nsdf-fuse $TARGET simple-benchmark seq-n-write
nsdf-fuse $TARGET simple-benchmark seq-n-read
nsdf-fuse $TARGET clean-bucket 

nsdf-fuse $TARGET simple-benchmark rand-n-write
nsdf-fuse $TARGET simple-benchmark rand-n-read
nsdf-fuse $TARGET clean-bucket 

nsdf-fuse $TARGET remove-bucket 
```

# S3 commands

```
# list buckets
aws s3 ls

# create bucket 
aws s3api create-bucket --bucket ${BUCKET_NAME} --region ${AWS_DEFAULT_REGION}

# remove bucket
aws s3 rb s3:://<bucket_name> --force

# list object inside bucket
aws s3 ls s3:://<bucket_name> 
```