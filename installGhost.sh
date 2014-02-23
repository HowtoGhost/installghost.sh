#!/bin/bash
# Written by Andy Boutte and David Balderston of howtoinstallghost.com and allaboutghost.com
# installGhost.sh will download and install all needed compontents to run Ghost

######Check to make sure script is being run as root######
if [[ `whoami` != root ]]; then
    echo "This script must be run as root"
    exit 1
fi

######Check to see what OS is being used and install dependencies######

/bin/uname -a > /tmp/osversion.txt

if grep "Ubuntu" "/tmp/osversion.txt" > /dev/null; then
    echo "Ubuntu"
    operSys="Ubuntu"
    apt-get -y update
    aptitude -y install build-essential zip
    useradd ghost
elif grep "SMP" "/tmp/osversion.txt" > /dev/null; then
    echo "CentOS"
    operSys="CentOS"
    yum -y update
    /usr/bin/yum -y groupinstall "Development Tools"
    adduser ghost
elif grep "Debian" "/tmp/osversion.txt" > /dev/null; then
    echo "Mac OS X"
fi

######Download and install Node######
cd /tmp/
wget http://nodejs.org/dist/node-latest.tar.gz
echo "node downloaded"
tar -xzf node-latest.tar.gz
echo "node unzipped"
rm node-latest.tar.gz

nodeversion=`ls | grep node`

cd $nodeversion
./configure
echo "node configured"
make -s
make install
echo "node installed"
cd /tmp
rm -rf $nodeversion

######Download Ghost######
mkdir -p /var/www
cd /var/www/
curl -L -O https://ghost.org/zip/ghost-latest.zip
unzip -d ghost ghost-latest.zip
rm ghost.zip
chown -R ghost:ghost /var/www/ghost/

######Install Nginx######
echo "installing nginx"
if ($operSys="Centos"); then
	/usr/bin/yum install nginx -y
else
	apt-get install nginx
fi
echo "starting nginx"

service nginx start
chkconfig nginx on
echo 'server { / location / { proxy_set_header X-Real-IP $remote_addr; proxy_set_header Host $http_host; proxy_pass http://127.0.0.1:2368; } }' > /etc/nginx/conf.d/virtual.conf
service nginx restart

echo "nginx complete"

######Switch to Ghost User######
su - ghost
cd /var/www/ghost/

######Install and Start Ghost######
/usr/local/bin/npm install --production
/usr/local/bin/npm start --production

######Edit the Config File######
#sed -e 's/127.0.0.1/0.0.0.0/' -e 's/2368/80/' <config.example.js >config.js

######Install PM2######
echo "starting pm2"
/usr/local/bin/npm install git://github.com/Unitech/pm2.git -g
NODE_ENV=production /usr/local/bin/pm2 start index.js --name ghost
s/usr/local/bin/pm2 dump
if ($operSys="Centos"); then
	/usr/local/bin/pm2 startup centos
else
	/usr/local/bin/pm2 startup Ubuntu
fi
sed -i '0,/USER=root/ s/USER=root/#USER=ghost/' /etc/init.d/pm2-init.sh

echo "pm2 complete"
