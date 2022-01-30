#!/bin/bash
# Z-Push for Modoboa install script v0.1 ALPHA
# This script is very messy and basic, calendar is not tested and is only set up to get easy configuration to mobile and outlook clients.
# No support provided, however someone in https://discord.gg/WuQ3v3PXGR might be able to help?

# Pre-flight check to see if Modoboa's default NginX config have been removed
tld=`awk -F "[, ]+" '/server_name/{print substr($3, 12, length($3)-12)}' /etc/nginx/sites-available/autoconfig.*.conf`
if [ "$tld" = "" ];
then
        echo "No Domain found, please enter a domain (note: must be DOMAIN.TLD format and not include subdomain)"
        read -p "Domain: " tld
fi

echo -e "Install PHP dependencies"
apt install -y php-fpm php-mbstring php-imap php-soap php-common php-xsl
phpenmod -v ALL imap
phpenmod -v ALL mbstring
phpenmod -v ALL soap
phpenmod -v ALL xsl

echo -e "Download Z-Push"
cd /tmp/
wget -O /tmp/z-push.zip https://github.com/Z-Hub/Z-Push/archive/refs/tags/2.6.4.zip

echo -e "Extract and move Z-Push into /srv/"
unzip /tmp/z-push.zip -d /tmp/
mv /tmp/Z-Push*/src /srv/z-push
rm -rf /tmp/Z-Push* /tmp/z-push.zip

echo -e "Create log dir and set permissions"
mkdir /var/log/z-push
chown www-data:adm /var/log/z-push
chmod 755 /var/log/z-push

echo -e "Setting Ownership to modoboa"
chown www-data:modoboa -R /srv/z-push


echo -e "Lets edit these Configs to work on Modoboa's setup"
sed -i "s/\/var\/lib\/z-push/\/srv\/z-push/g" /srv/z-push/config.php
sed -i "s/BACKEND_PROVIDER', ''/BACKEND_PROVIDER', 'BackendIMAP'/g" /srv/z-push/config.php
sed -i "s/USE_FULLEMAIL_FOR_LOGIN', false/USE_FULLEMAIL_FOR_LOGIN', true/g" /srv/z-push/config.php
sed -i "s/STATE_DIR', '\/var\/lib\/z-push\//STATE_DIR', '\/srv\/z-push\/lib\//g" /srv/z-push/config.php
sed -i "s/IMAP_PORT', 143/IMAP_PORT', 993/g" /srv/z-push/backend/imap/config.php
sed -i "s/IMAP_OPTIONS', '\/notls\/norsh/IMAP_OPTIONS', '\/ssl\/novalidate-cert/g" /srv/z-push/backend/imap/config.php
sed -i "s/IMAP_FOLDER_CONFIGURED', false/IMAP_FOLDER_CONFIGURED', true/g" /srv/z-push/backend/imap/config.php
sed -i "s/IMAP_FOLDER_SPAM', 'SPAM'/IMAP_FOLDER_SPAM', 'JUNK'/g" /srv/z-push/backend/imap/config.php
sed -i "s/USE_FULLEMAIL_FOR_LOGIN', false/USE_FULLEMAIL_FOR_LOGIN', true/g" /srv/z-push/autodiscover/config.php
sed -i "s/BACKEND_PROVIDER', ''/BACKEND_PROVIDER', 'BackendIMAP'/g" /srv/z-push/autodiscover/config.php

echo -e "Time to edit the NignX configs"
cd /etc/nginx/sites-available
phpfpmpath=`find /run/php/ -name "php*-fpm.sock" |head -n 1`

echo -e "Backing up the NginX configs \n"
cp -a /etc/nginx/sites-available/autoconfig.$tld.conf /etc/nginx/sites-available/autoconfig.$tld.conf.bkup-`date +"%F-%T"`
cp -a /etc/nginx/sites-available/mail.$tld.conf /etc/nginx/sites-available/mail.$tld.conf.bkup-`date +"%F-%T"`

echo -e "Domain's TLD is "$tld" We need to know this to make the changes"

echo -e "Creating a new autoconfig/autodiscover config for port 80"
printf "# This file was automatically installed on `date +"%F-%T.%s"`
server {
    listen 80;
    listen [::]:80;
    server_name autoconfig.$tld;
    root /srv/z-push;

    access_log /var/log/nginx/autoconfig.$tld-access.log;
    error_log /var/log/nginx/autoconfig.$tld-error.log;

    # Z-Push (Microsoft Exchange ActiveSync)
    location /Microsoft-Server-ActiveSync {
        include /etc/nginx/fastcgi_params;
        fastcgi_pass unix:$phpfpmpath;
        fastcgi_param SCRIPT_FILENAME /srv/z-push/index.php;
        fastcgi_param PHP_VALUE "include_path=.:/usr/share/php:/usr/share/pear";
        fastcgi_read_timeout 630;

        client_max_body_size 128M;
    }

    # Z-Push Z-Push (Auto Discover)
    location ~* ^/autodiscover/autodiscover.xml {
        include /etc/nginx/fastcgi_params;
        fastcgi_pass unix:$phpfpmpath;
        fastcgi_param SCRIPT_FILENAME /srv/z-push/autodiscover/autodiscover.php;
        fastcgi_param PHP_VALUE "include_path=.:/usr/share/php:/usr/share/pear";
    }
}" > /etc/nginx/sites-available/autoconfig.$tld.conf

echo -e "Time to edit the main Mail config (HTTPS/443)"
echo -e "Search for the old automx settings and comment them out"
sed -i -r "/location/{/\n/{P;D;};:1;N; /\}/!b1;/automx/s/[^\n]*\n*\n*/#&/g}" /etc/nginx/sites-available/mail.$tld.conf

echo -e "Inserting Date into line 2"
sed -i "2 i \# Config edited for z-Push `date +%F-%T.%s`\n" /etc/nginx/sites-available/mail.$tld.conf

echo -e "Inserting new "
sed -i "\$i\
\    # Z-Push (Microsoft Exchange ActiveSync)\n\
    location /Microsoft-Server-ActiveSync {\n\
        include /etc/nginx/fastcgi_params;\n\
        fastcgi_pass unix:$phpfpmpath;\n\
        fastcgi_param SCRIPT_FILENAME /srv/z-push/index.php;\n\
        fastcgi_param PHP_VALUE "include_path=.:/usr/share/php:/usr/share/pear";\n\
        fastcgi_read_timeout 630;\n\
        client_max_body_size 128M;\n\
    }\n\
\n\
    # Z-Push Z-Push (Auto Discover)\n\
    location ~* ^/autodiscover/autodiscover.xml$ {\n\
        include /etc/nginx/fastcgi_params;\n\
        fastcgi_pass unix:$phpfpmpath;\n\
        fastcgi_param SCRIPT_FILENAME /srv/z-push/autodiscover/autodiscover.php;\n\
        fastcgi_param PHP_VALUE "include_path=.:/usr/share/php:/usr/share/pear";\n\
    }\n\
" /etc/nginx/sites-available/mail.$tld.conf

echo -e "Restarting NginX to apply the changes"

service nginx restart

echo -e "All Done!"
