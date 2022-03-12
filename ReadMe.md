# Instructions

Define the credentials for the S3 backend (change as needed):

```
export ACCESS_KEY=XXXXX
export SECRET_ACCESS_KEY=YYYYY
export BUCKET_REGION=us-east-1

# For ObjectiveFs you also need to setup this
export OBJECTIVEFS_LICENSE=ZZZZZ

# for juicefs you should create File system
```

Run a test:

```
./s3fs.sh

# each test will use the following base directory (see InitFuseTest)
# ${HOME}/mount/${BUCKET_NAME} where BUCKET_NAME is for example nsdf-fuse-test-s3fs
```


# Benchmarks