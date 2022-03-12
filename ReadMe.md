# Instructions

Define the credentials for the S3 backend (change as needed):

```
export ACCESS_KEY=XXXXX
export SECRET_ACCESS_KEY=YYYYY
export BUCKET_REGION=us-east-1
```

For ObjectiveFs you also need to setup this:

```
export OBJECTIVEFS_LICENSE=ZZZZZ
```

To run tests for example:

```
NAME=s3fs
./${NAME}.sh
```

A test will use the following base directory (see `InitFuseTest`):

```
${HOME}/mount/${BUCKET_NAME}
```

where `BUCKET_NAME` is `nsdf-fuse-test-${NAME}`:



# Benchmarks