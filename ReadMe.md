# Instructions

Update OS and install dependencies:

```
sudo apt -qq update
sudo apt -qq install -y nload expect python3 python3-pip awscli fuse libfuse-dev 
```

Clone this repository:

```
git clone https://github.com/nsdf-fabric/nsdf-fuse-test
cd nsdf-fuse-test
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

```

Install `goofys`:

```
wget https://github.com/kahing/goofys/releases/latest/download/goofys
sudo mv goofys /usr/bin/
chmod a+x /usr/bin/goofys
```

Install `juicefs`:

```
wget -q https://juicefs.com/static/juicefs
sudo mv juicefs /usr/bin
chmod +x /usr/bin/juicefs 
```

Also for `juicefs` you need to create a File System named `juicefs-nsdf-fuse-test-juicefs` (see https://juicefs.com/console/).


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
```

Install `rclone` and set credentials:

```
wget https://downloads.rclone.org/v1.57.0/rclone-v1.57.0-linux-amd64.deb
sudo dpkg -i rclone-v1.57.0-linux-amd64.deb
rm rclone-v1.57.0-linux-amd64.deb

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
```

Install `s3backer`:

```
sudo apt install -y s3backer
sudo sh -c 'echo user_allow_other >> /etc/fuse.conf'
```

Install `s3fs` and setup credentials:

```
sudo apt install -y s3fs 
echo ${AWS_ACCESS_KEY_ID}:${AWS_SECRET_ACCESS_KEY} > ${HOME}/.s3fs
chmod 600 ${HOME}/.s3fs
```

Install `s3ql` and setup credentials (NOTE fuse3 is not compatible with fuse so you will need to run this test alone):

```
sudo apt install -y sqlite3 libsqlite3-dev pkg-config libfuse3-dev
# sudo apt remove fuse 
# sudo apt install -y fuse3 
sudo pip3 install --upgrade pip
sudo pip3 install --upgrade pyfuse3 google-auth-oauthlib dugong apsw defusedxml trio

wget https://github.com/s3ql/s3ql/releases/download/release-3.8.1/s3ql-3.8.1.tar.gz
tar xzf s3ql-3.8.1.tar.gz
pushd s3ql-3.8.1
python3 setup.py build_ext --inplace
sudo python3 setup.py install 
popd
sudo rm -Rf s3ql-3.8.1.tar.gz s3ql-3.8.1

mkdir -p ${HOME}/.s3ql/
cat << EOF > ~/.s3ql/authinfo2
[s3-test]
storage-url: s3://${AWS_DEFAULT_REGION}/${BUCKET_NAME}
backend-login: ${AWS_ACCESS_KEY_ID}
backend-password: ${AWS_SECRET_ACCESS_KEY}
EOF
chmod 600 ~/.s3ql/authinfo2
```

# Run test

Example:

```

# TODO s3ql
for it in geesefs goofys juicefs objectivefs rclone s3backer s3fs ; do
   ./test.sh $it create-bucket

   ./test.sh geesefs seq-1-write
   ./test.sh geesefs seq-1-read
   ./test.sh geesefs clean-bucket

   ./test.sh geesefs seq-n-write
   ./test.sh geesefs seq-n-read
   ./test.sh geesefs clean-bucket

   ./test.sh geesefs rnd-n-write
   ./test.sh geesefs rnd-n-read
   ./test.sh geesefs clean-bucket

   ./test.sh geesefs tar-gz
   ./test.sh geesefs clean-bucket

   ./test.sh $it remove-bucket

done

```

