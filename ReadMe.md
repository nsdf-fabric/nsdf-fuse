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

# uncomment this if you want to just test quickly the scripts
# export FAST=1

```

Run one of the test:

```
git clone https://github.com/nsdf-fabric/nsdf-fuse-test
cd nsdf-fuse-test


export AWS_ACCESS_KEY_ID=XXXXX
export AWS_SECRET_ACCESS_KEY=YYYYY
export AWS_DEFAULT_REGION=us-east-1
export OBJECTIVEFS_LICENSE=ZZZZZ     # only if you test objectivefs
export JUICE_TOKEN=KKKKK             # only if you test juice

seq-1-write
seq-1-read
seq-n-write
seq-n-read
rnd-n-write
rnd-n-read
tar-gz
rm-files


./geesefs.sh     > output.1.geesefs      2>&1
./goofys.sh      > output.1.goofys       2>&1  
./juicefs.sh     > output.1.juicefs      2>&1
./objectivefs.sh > output.1.objectivefs  2>&1
./rclone.sh      > output.1.rclone       2>&1
./s3backer.sh    > output.1.s3backer     2>&1
./s3fs.sh        > output.1.s3fs         2>&1
./s3ql.sh        > output.1.s3ql         2>&1

# you can extract the part this way
for f in geesefs goofys juicefs objectivefs rclone s3backer s3fs s3ql; do
   echo $f
   grep " write: IOPS\| read: IOPS\|real " output.1.$f  | cut -d" " -f2,3,4,5 
   echo
done
```


# Misc:

To clean up broken test:

```
for it in $(mount | grep mount)
do 
    echo $it
done

rm -Rf ~/mount

for it in $(aws s3 ls | cut -d" " -f3)
do 
    aws s3 rb s3://$it --force 
done
``
