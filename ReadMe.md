# Software


|name        |need server|chunked | multi-user                                              |limitations                          |
|------------|-----------|--------|---------------------------------------------------------|-------------------------------------|
|s3backer    | no        | yes    | https://github.com/archiecobbs/s3backer                 |                                     |
|s3fs        | no        | no     | should work with multiple reads                         |                                     |
|s3ql        | no        | yes    | should work with multiple reads                         |                                     |
|rclone      | no        | no     | should work with multiple reads                         |                                     |
|geesefs     | no        | yes    | https://github.com/yandex-cloud/geesefs                 |                                     |
|goofys      | no        | yes    | https://github.com/kahing/goofys/issues/174             |no rand-write                        |
|juicefs     | yes       | yes    | https://github.com/juicedata/juicefs/discussions/1054   |                                     |
|objectivefs | no        |yes     | https://objectivefs.com/features                        |                                     |


# Instructions

Update OS and install dependencies:

```
sudo apt -qq update
sudo apt -qq install -y nload expect python3 python3-pip awscli fuse libfuse-dev net-tools
```

Clone this repository:

```
git clone https://github.com/nsdf-fabric/nsdf-fuse-test
cd nsdf-fuse-test
export PATH=$PWD:$PATH
```


Define the credentials for the the tests (change as needed):

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

Install lastest versio of `fio`:

```
git clone https://github.com/axboe/fio
pushd fio
./configure
make 
sudo make install
sudo cp /usr/local/bin/fio /usr/bin/fio 
popd
rm -Rf fio

# check the version
fio --version
```

Install `geesefs` and create credentials:

```
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
```

Install `goofys`:

```
wget https://github.com/kahing/goofys/releases/latest/download/goofys
sudo mv goofys /usr/bin/
chmod a+x /usr/bin/goofys

# check the version
goofys --version
```

Install `juicefs`

NOTE you need to create a File System named `juicefs-nsdf-fuse-test-juicefs` (see https://juicefs.com/console/).

```
wget -q https://juicefs.com/static/juicefs
sudo mv juicefs /usr/bin
chmod +x /usr/bin/juicefs

# check the version
juicefs version
```

Install `objectivefs` and create credentials:

```
wget -q https://objectivefs.com/user/download/asn7gu3nd/objectivefs_6.9.1_amd64.deb
sudo dpkg -i objectivefs_6.9.1_amd64.deb
rm objectivefs_6.9.1_amd64.deb

sudo mkdir -p /etc/objectivefs.env
sudo rm -Rf /etc/objectivefs.env/*
sudo bash -c "echo ${AWS_ACCESS_KEY_ID}      > /etc/objectivefs.env/AWS_ACCESS_KEY_ID"
sudo bash -c "echo ${AWS_SECRET_ACCESS_KEY}  > /etc/objectivefs.env/AWS_SECRET_ACCESS_KEY"
sudo bash -c "echo ${AWS_DEFAULT_REGION}     > /etc/objectivefs.env/AWS_DEFAULT_REGION"
sudo bash -c "echo ${OBJECTIVEFS_LICENSE}    > /etc/objectivefs.env/OBJECTIVEFS_LICENSE"
sudo bash -c "echo ${OBJECTIVEFS_LICENSE}    > /etc/objectivefs.env/OBJECTIVEFS_PASSPHRASE"
sudo chmod 600 /etc/objectivefs.env/*

# check the version
mount.objectivefs help 
```

Install `rclone` and set credentials:

```
wget https://downloads.rclone.org/v1.57.0/rclone-v1.57.0-linux-amd64.deb
sudo dpkg -i rclone-v1.57.0-linux-amd64.deb
rm rclone-v1.57.0-linux-amd64.deb

mkdir -p ~/.config/rclone/
cat << EOF >> ~/.config/rclone/rclone.conf
[nsdf-test-rclone]
type=s3
provider=Other
access_key_id=${AWS_ACCESS_KEY_ID}
secret_access_key=${AWS_SECRET_ACCESS_KEY}
region=${AWS_DEFAULT_REGION} 
endpoint=https://s3.${AWS_DEFAULT_REGION}.amazonaws.com
EOF
chmod 600 ~/.config/rclone/rclone.conf

# check the version
rclone --version
```

Install `s3backer`:

```
sudo apt install -y s3backer
sudo sh -c 'echo user_allow_other >> /etc/fuse.conf'

# check the version
s3backer --version
```

Install `s3fs` (NOTE: install from scratch, old version is buggy) and setup:

```
sudo apt-get install autotools-dev automake libcurl4-openssl-dev libxml2-dev libssl-dev
git clone https://github.com/s3fs-fuse/s3fs-fuse.git
cd s3fs-fuse
./autogen.sh
./configure
make
sudo make install
sudo mv /usr/local/bin/s3fs /usr/bin/
echo ${AWS_ACCESS_KEY_ID}:${AWS_SECRET_ACCESS_KEY} > ${HOME}/.s3fs
chmod 600 ${HOME}/.s3fs

s3fs --version
```

Install `s3ql` and setup credentials 

**NOTE fuse3 is not compatible with fuse, used by most of other software, so you will need to run this s3ql at the end**:

```
sudo apt remove fuse 
sudo apt install -y \
    sqlite3 libsqlite3-dev pkg-config \
    libfuse3-dev fuse3

sudo pip3 install --upgrade pip
sudo pip3 install --upgrade \
    pyfuse3 google-auth-oauthlib dugong apsw defusedxml trio

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
```


After the test repristinate the normal fuse:

```
sudo apt remove  -y fuse3
sudo apt install -y fuse
```

# Tests

Examples:

```
# what do you want to use
TARGET=juicefs

# this command create the S3 bucket ready to be used
# in certain cases it will 'format' the bucket as it was a filesystem
nsdf-fuse $TARGET create-bucket

# mount the object storage into a POSIX-like directory
nsdf-fuse $TARGET up

# create an example file
nsdf-fuse $TARGET touch

# find all files inside the object store
nsdf-fuse $TARGET find

# unmount the object storage filesystem. it removes all the caches
# it's like rebooting the computer to loose any cache and repeat the tests
nsdf-fuse $TARGET down

# totally destroy the bucket, to run only when the file system it's not going to be used in the future
# (or for testing)
nsdf-fuse $TARGET remove-bucket

# run fio tests (to run all leave empty)
nsdf-fuse $TARGET   [benchmark-fio-big-file-sequential-read | 
                     benchmark-fio-big-file-sequential-write | 
                     benchmark-fio-big-file-multi-read | 
                     benchmark-fio-big-file-multi-write | 
                     benchmark-fio-big-file-rand-read]

# run simple disk test (to run all leave empty)
nsdf-fuse $TARGET [ benchmark-simple-seq-1 | benchmark-simple-seq-n | benchmark-simple-rand-n ]

# dangerous, please carefully read  the code before executing
# == force a full cleaning of all buckets, mounts, files, caches etc
# lot of paths are hardcoded
nsdf-fuse clean-all

# to do a check of all software
# paths hardcoded
nsdf-fuse quick-check

# some S3 command that could help in debugging
aws s3 ls
aws s3 rb s3:://<bucket_name> --force
aws s3 ls s3:://<bucket_name> 

```

