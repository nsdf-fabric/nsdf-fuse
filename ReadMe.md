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
curl -L https://github.com/nsdf-fabric/nsdf-fuse-test/tarball/master | tar -xz
cd nsdf-fabric-nsdf-fuse-test-*

./geesefs.sh
./goofus.sh
./juicefs.sh
./objectivefs.sh
./s3backer.sh
./s3fs.sh
./s3ql.sh

# each test will use the following base directory (see InitFuseTest)
# ${HOME}/mount/${BUCKET_NAME} where BUCKET_NAME is for example nsdf-fuse-test-s3fs
```


# Benchmarks

```
TODO
```