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
    apt-get -y update
    aptitude -y install build-essential zip
elif grep "SMP" "/tmp/osversion.txt" > /dev/null; then
    echo "CentOS"
    yum -y update
    /usr/bin/yum -y groupinstall "Development Tools"
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

######Download and install Ghost######
mkdir -p /var/www
cd /var/www/
curl -L -O https://ghost.org/zip/ghost-latest.zip
unzip -d ghost ghost-latest.zip
rm ghost-latest.zip
cd ghost/
/usr/local/bin/npm install --production

######Edit the Config File######
sed -e 's/127.0.0.1/0.0.0.0/' -e 's/2368/80/' <config.example.js >config.js

######Install Forever######
/usr/local/bin/npm install -g forever

#####Setup Forever Start Script######
echo "#!/bin/bash" >> /usr/local/bin/ghoststart.sh
echo "export PATH=/usr/local/bin:$PATH" >> /usr/local/bin/ghoststart.sh
echo "cd /var/www/ghost" >> /usr/local/bin/ghoststart.sh
echo "export NODE_ENV=production" >> /usr/local/bin/ghoststart.sh
echo "NODE_ENV=production /usr/local/bin/forever -a -l /var/log/ghost start --sourceDir /var/www/ghost index.js" >> /usr/local/bin/ghoststart.sh
chmod 755 /usr/local/bin/ghoststart.sh

######Create Startup Cron######
echo "@reboot /usr/local/bin/ghoststart.sh" > mycron
crontab mycron
rm mycron

######Start Ghost with Forever######
sh /usr/local/bin/ghoststart.sh