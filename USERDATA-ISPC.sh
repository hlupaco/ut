#!/bin/bash

DOMAIN=mm.utdigit.com
#webadmin password, POZOR max delka je 10 charu
SSHPW='318250'
#ISPCADMINPW='admin'
#MYSQLADMINPW='318250'
#SUBDOMAIN=$(echo "$DOMAIN" | cut -d. -f1)
#DNSZONE=$(echo "$DOMAIN" | cut -d. -f2-)

IP=$(ip addr show eth0 | grep 'inet' | grep -v 'inet6' | tr -s ' ' | cut -d' ' -f3 | cut -d'/' -f1)

USER='ubuntu'

#https://yarnpkg.com/lang/en/docs/install/#linux-tab

#toto zmenit? az podle prani Kofa
composer self-update 1.1.3

apt-get -y update
apt-get -y upgrade
apt-get -y autoremove



#for some reason this is needed or ispconfig fcks up
apt -y install mysql-server
#echo "[mysqld]" >> /etc/mysql/my.cnf
#echo 'sql-mode="NO_ENGINE_SUBSTITUTION"' >> /etc/mysql/my.cnf



cd "/home/$USER/ispconfig3_install/install/"
echo '#!/usr/bin/expect
spawn php -q update.php 
expect "ISPConfig backup"
send "no\n"
expect "Reconfigure Permissions"
send "\n"
expect "mail_server"
send "\n"
expect "dns_server"
send "\n"
expect "firewall_server"
send "\n"
expect "Reconfigure Services"
send "\n"
expect "ISPConfig Port"
send "\n"
expect "ISPConfig SSL cert"
send "no\n"
expect "Reconfigure Crontab"
send "\n"' > ISPC_update.exp 
chmod u+x ISPC_update.exp
./ISPC_update.exp



#find / -name phpmyadmin | xargs chgrp -R www-data
#find / -name phpmyadmin | xargs chmod -R g+w



#firewall
#ufw allow 22/tcp
#ufw allow 80/tcp
#ufw allow 443/tcp
#ufw allow 8080/tcp
#ufw enable
#ufw status



#make user webadmin overall with group www-data
cd
echo '#!/usr/bin/expect
spawn openssl passwd
expect "assword:"
send "'"$SSHPW"'\n"
expect "assword:"
send "'"$SSHPW"'\n"
expect eof' > cryptpw.exp

chmod u+x cryptpw.exp

useradd webadmin
usermod -a -G www-data webadmin
SSHPW_CRYPT="$(./cryptpw.exp | tail -n1)"
usermod -p "'$'" webadmin

#TODO: letsencrypt - grab new cert for $DOMAIN
#also gonna need to add automatic renewal script

#TODO: cleanup if needed

#TODO: log file of this script?



exit 0
