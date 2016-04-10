#!/bin/bash

# Written by Andy Boutte and David Balderston of howtoinstallghost.com and allaboutghost.com
# installGhost.sh will download and install all needed compontents to run Ghost

clear

echo ""

######Check to make sure script is being run as root######
if [ `whoami` != root ]; then
    echo "This script must be run as root"
    exit 1
fi

echo "This script installs Nginx and Ghost on Ubuntu"
echo "To configure Nginx and Ghost please provide your hostname:"
echo ""
read HOSTNAME

######Check to make sure we are running on Ubuntu######

if ! $(uname -a | grep -q Ubuntu); then
    echo "Only Ubuntu is supported"
    exit
fi

######Download and install Node######
apt-get -y update
apt-get -y upgrade
curl -sL https://deb.nodesource.com/setup | sudo bash -
apt-get install -y nodejs zip nginx

######Download and install Ghost######
mkdir -p /var/www
cd /var/www/
curl -L -O https://ghost.org/zip/ghost-latest.zip
unzip -d ghost ghost-latest.zip
rm ghost-latest.zip
cd ghost/
sed -e "s/my-ghost-blog.com/$HOSTNAME/" <config.example.js >config.js
/usr/bin/npm install --production

#######Setup Ghost User######
adduser --shell /bin/bash --gecos 'Ghost application' ghost --disabled-password
echo ghost:ghost | chpasswd
chown -R ghost:ghost /var/www/ghost/

######Config Nginx######
echo "configuring Nginx"
echo "server {" >> /etc/nginx/sites-available/ghost
echo "    listen 80;" >> /etc/nginx/sites-available/ghost
echo "    server_name $HOSTNAME;" >> /etc/nginx/sites-available/ghost
echo "    location / {" >> /etc/nginx/sites-available/ghost
echo "        proxy_set_header   X-Real-IP \$remote_addr;" >> /etc/nginx/sites-available/ghost
echo "        proxy_set_header   Host      \$http_host;" >> /etc/nginx/sites-available/ghost
echo "        proxy_pass         http://127.0.0.1:2368;" >> /etc/nginx/sites-available/ghost
echo "        }" >> /etc/nginx/sites-available/ghost
echo "    }" >> /etc/nginx/sites-available/ghost

ln -s /etc/nginx/sites-available/ghost /etc/nginx/sites-enabled/ghost

rm /etc/nginx/sites-available/default
rm /etc/nginx/sites-enabled/default
service nginx restart

######Install PM2######
echo "#!/bin/bash" >> /home/ghost/start.sh
echo "export NODE_ENV=production" >> /home/ghost/start.sh
echo "cd /var/www/ghost/" >> /home/ghost/start.sh
echo "npm start --production" >> /home/ghost/start.sh
chmod +x /home/ghost/start.sh

/usr/bin/npm install -g pm2

su -c "echo 'export NODE_ENV=production' >> ~/.profile" -s /bin/bash ghost
su -c "source ~/.profile" -s /bin/bash ghost
su -c "/usr/bin/pm2 kill" -s /bin/bash ghost
su -c "env /usr/bin/pm2 start /home/ghost/start.sh --interpreter=bash --name ghost" -s /bin/bash ghost
env PATH=$PATH:/usr/bin pm2 startup ubuntu -u ghost --hp /home/ghost
su -c "pm2 save" -s /bin/bash ghost
