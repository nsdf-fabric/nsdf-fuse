# Instructions

Define the credentials for the S3 backend (change as needed):

```
export ACCESS_KEY=XXXXX
export SECRET_ACCESS_KEY=YYYYY
export BUCKET_REGION=us-east-1

# # this is needed only for ObjectiveFS test
export OBJECTIVEFS_LICENSE=ZZZZZ 

# this is needed only for JuiceFs 
# you must create a "File System" (see https://juicefs.com/console/)
# with name `nsdf-fuse-test-juicefs`
export JUICE_TOKEN=KKKKK
```

Run one of the test:

```
git clone https://github.com/nsdf-fabric/nsdf-fuse-test
cd nsdf-fuse-test

# NOTE: each test will use the following base directory (see InitFuseTest)
#       ${HOME}/mount/${BUCKET_NAME} where BUCKET_NAME is for example nsdf-fuse-test-s3fs


./juicefs.sh      # fast OK
./goofys.sh       # fast OK
./geesefs.sh      # slow 
./objectivefs.sh  # slow 
./s3backer.sh     # slow 
./s3fs.sh         # slow
./s3ql.sh         # slow 
./rclone.sh       # slow
```

# Benchmarks

```
TODO
```