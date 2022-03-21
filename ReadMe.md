# NSDF-Fuse Repository

This repository is made of a single bash script `nsdf-fuse` to mount/unmount, test and benchmark `Object Storage` mounted as a FUSE filesystem.

This is not optimal file/data access, since the preferite way is always to use direcly the S3 API, but nevertherless it is useful to 
investigate how Object Storage will behave if mounted as a file system.

Specific instructions for specific vendors are contained inside `scripts/` directory. For example inside the `scripts/geesefs.sh` 
you will find code to mount/unmount using the GeeseFS solution.

The solutions currently explored/investigated are:

- `GeeseFS`  a good FUSE FS implementation over S3 (link https://github.com/yandex-cloud/geesefs)

- `Goofys` a high-performance, POSIX-ish Amazon S3 file system written in Go (link: https://github.com/kahing/goofys)

- `JuiceFs` a distributed POSIX file system built on top of Redis and S3.  (link: JuiceFS is a distributed POSIX file system built on top of Redis and S3.)

- `ObjectiveFS` a  shared file system that scales automatically, with unlimited storage and high performance (link: https://objectivefs.com/)

- `RClone` is a "rsync for cloud storage" (link: https://github.com/rclone/rclone)

- `S3Backer` is a FUSE-based single file backing store via Amazon S3 (link: https://github.com/archiecobbs/s3backer)

- `S3FS` FUSE-based file system backed by Amazon S3 (link: https://github.com/s3fs-fuse/s3fs-fuse)

- `S3QL` a full featured file system for online data storage (link: https://github.com/s3ql/s3ql)

The benchmark that could be run are not meant to be optimized for showing the effectiviness of caching. 

On the contrary we are tyring to simulate use cases where data is not cached, with **cold** access like after a boot, and mounting a brand new bucket.

In general we focused our investigations to the following cases:

- sequential write with just one writer with big files (e.g. some `1GiB` files)

- sequential read  with just one reader with big files (e.g. some `1GiB` files)

- sequential write with multiple writers concurrently accessing big files (e.g. some `1GiB` files)

- sequential read  with multiple readers concurrently accessing big files (e.g. some `1GiB` files)

- random writes with multiple writers accessing small files (e.g. lots of `64KiB` files)

- random reads  with multiple readers accessing small files (e.g. lots of `64KiB` files)

we built test so that the same file is not accessed twice, this is to avoid any caching factor.

# Considerations

Some notes/considerations before starting testing by your own:

- there are some very dangerous command that could be run (like `clean-all`). It'a better to use this tests on accounts where you are sure you can afford to loose all the buckets associated.

- We are more interested in reading than writing. Without some advanced locking-mechanism is practically impossible to have
  concurrent writing without having later big problems or, even worst, a corrupted file system
  
- Running `fio` benchmark we get inconsistent/unbelievable results. This could be related to the fact that we don't have
  any control on operations going on internally and it's difficult to understand/control the caching effect.

- We prefer free (i.e. not commercial solution) solutions. The only pay-per-use solution here is `ObjectiveFS`

- We prefer serverless solution, to cut down cost of maintanance and hardware. The only  `servfull` solution here is `JuiceFs`.

- All tests are repeated at least 3 times. This is to avoid the *cloud noisy neighbor (ref https://www.techtarget.com/searchcloudcomputing/definition/noisy-neighbor-cloud-computing-performance). But to have real numbers probably we need to repeat tests multiple times, in different days/regions/platforms/hour ranges etc.

- All tests are run internally in one region. For example if the data is stored
  in the `us-east-1` AWS region, then the FUSE file system is mounter/run/used
  on a virtual machine (AWS Ec2 instance) running in the same region. We don't
  care too much here about latency induced by geographic distance, but we want to
  investigate more on the intrinsic limitation induced by the FUSe mounting.

# NSDF-FUSE setup

We need one AWS S3 account to run all test.

**As said before, make sure you don't have data in production you cannot afford to loose during the benchmarks**.

All the tests use by default Amazon S3. The code could be easily (?) generalized to specify different endpoints for example to  S3-like vendors (e.g. Wasabi/OSN). It will be interesting to double check if we will get very different behaviours with different vendors.

To start the testing we first need to define the access key, secret access key and region to be used (change as needed):

```
export AWS_ACCESS_KEY_ID=XXXXX
export AWS_SECRET_ACCESS_KEY=YYYYY
export AWS_DEFAULT_REGION_REGION=us-east-1
```

## ObjectiveFS setup

To test ObjectiveFS you need to register [here](https://objectivefs.com/account/signup?l=signup). Pricing details are available [here](https://objectivefs.com/price?l=pricing). You can create a 14-days try-and-buy version. At the end of the registration process you will get a licence to be specified on your terminal (change as needed):

```
export OBJECTIVEFS_LICENSE=ZZZZZ 
```

## JuiceFS setup

To test JuiceFs you will need a Redis server for metadata. You could use a SaaS Service [here](https://juicefs.com/docs/cloud/) that is free up to `1TiB` with 10 mounts (see [pricing link](https://juicefs.com/pricing)). After the registration you need to create a `File System` in https://juicefs.com/console/ named `nsdf-fuse-test-juicefs`. And you need to export the JuiceFS token into your terminal:

```
export JUICE_TOKEN=KKKKK
```



# How to run the test

First you need to create a VM (e.g. AWS Ec2 instances) possibly as near as possible your bucket; for example you want to create the VM and the bucket in the same region (e.g. `us-east-1`).

You need to setup the virtual machine with all the dependencies. 

```
nsdf-fuse update-os
nsdf-fuse install-fio
```


Clone this repository:

```
git clone https://github.com/nsdf-fabric/nsdf-fuse-test
cd nsdf-fuse-test
export PATH=$PWD:$PATH
```

<br>
Then you need to install the binaries to run tests. For example to install` geesefs` you can do:

```
TARGET=geesefs
nsdf-fuse $TARGET install
```

<br>
To create a test bucket you can do:

```
nsdf-fuse $TARGET create-bucket
```

<br>
this will create a bucket named `nsdf-fuse-test-$TARGET`.


To mount the bucket as a FUSE file system:

```
nsdf-fuse $TARGET up
```

<br>
To create a random file with random content:

```
nsdf-fuse $TARGET touch
```

<br>
To list all files inside the bucket:

```
nsdf-fuse $TARGET find
```

<br>
To unmount the FUSE file system and remove all cache so far created (thus simulating later a cold boot):

```
nsdf-fuse $TARGET down
```

<br>
To completely remove the test bucket (NOTE: this will destroy any data inside it!):

```
nsdf-fuse $TARGET remove-bucket
```

<br>
A last **VERY DANGEROUS** command is the `clean-all` command that will remove all buckets associated with the AWS account. Do not use for production accounts:

```
# DANGEROUS 
# It forces a full cleaning (==destroy) of all buckets, mounts, files, caches etc
# lot of paths are hardcoded
nsdf-fuse clean-all
```


# Run benchmarks

Update your VM and install binaries for each vendor (note that `s3ql` is not compatible with others):

```
nsdf-fuse   update-os
nsdf-fuse   install-fio
nsdf-fuse   geesefs     install
nsdf-fuse   goofys      install
nsdf-fuse   juicefs     install
nsdf-fuse   objectivefs install
nsdf-fuse   rclone      install
nsdf-fuse   s3backer    install
nsdf-fuse   s3fs        install
# nsdf-fuse s3ql        install (COMMENTED, see paragraph below)
```

<br>
Then you can repeat the test for a specific targets.

<br>

**NOTE: I am using `clean-all` and I am removing all files from `/tmp` here; so make sure you can afford to loose all buckets and loose all `/tmp` files**

```
echo "***********************************************"
echo " *** VERY VERY dangerous here               ***"
echo " *** I am destroying all buckets            ***"
echo " *** and removing all /tmp/* files          ***"
echo " *** make sure this is what you really want ***"
echo " **********************************************"

read -p "Are you sure? " -n 1 -r
echo    # (optional) move to a new line
if [[ ! $REPLY =~ ^[Yy]$ ]]
then

   TARGET=geesefs

	# this is simple test
   nsdf-fuse clean-all && \
     sudo rm -Rf /tmp/* && \
     nsdf-fuse $TARGET create-bucket && \
     nsdf-fuse $TARGET simple-benchmark 

	# this is FIO test
   nsdf-fuse clean-all && \
     sudo rm -Rf /tmp/* && \
     nsdf-fuse $TARGET create-bucket && \
     nsdf-fuse $TARGET fio-benchmark 

fi
```

# S3QL specific

`s3ql` is the only not compatible with other tests since it is using `fuse3` vs the normal `fuse` used by other TARGETS. 

You first install `s3ql` (automatically disabling all other tests):

```
nsdf-fuse s3ql install
```

Then you can run the `s3sq` tests as above. 

And finally you can re-enable other tests (i.e. re-enable `fuse` by removing `fuse3`):


```
nsdf-fuse s3ql uninstall
```


# Some sparse/ useful commands


Check network traffic:

```
nload -u M -U M
```

List S3 buckets:

```
aws s3 ls
```

Create bucket:

```
aws s3api create-bucket --bucket ${BUCKET_NAME} --region ${AWS_DEFAULT_REGION}
```

Remove bucket:

```
aws s3 rb s3:://<bucket_name> --force
```

List object inside bucket:

```
aws s3 ls s3:://<bucket_name> 
```
