#!/bin/bash
#fill in values until you see smiley

DOMAIN=mm.utdigit.com
SSHPW='318250' #user 'webadmin', POZOR max delka je 10 charu
JC="false" #set "true" if this server should be added to JC
MYSQL_ROOTPW='changeme' #leave empty for default '318250'
ISPC_ADMINPW='admin' #TODO: maybe change this so default pw is something else O_O
IP="" #write "assign" to assign an elastic IP, and grab new one if there is no free
#firewall - scroll down and uncomment / edit manually

#note - I havent tried out the automatic AWS CLI yet, IP assign may bug

#note - DNS doesnt work yes
#TODO: Automatic DNS intended only for ???.utdigit.com
DNS_CREATE="false" #set "true" to create new DNS record in Route53

touch /tmp/USERDATA_WORKING /home/ubuntu/USERDATA_WORKING

 ######
#      #
# O  O #
#  -   #
# \__/ #
#      #
 ######

InitiateDnsChangeFile () {

  filepath=$(GetTempFile)

  echo '{
  "Comment": "",
  "Changes": [
    {
      "Action": "UPSERT",
      "ResourceRecordSet": {
        "Name": "",
        "Type": "A",
        "TTL": 300,
        "ResourceRecords": [
          {
            "Value": ""
          }
        ]
      }
    }
  ]
}' >> "$filepath"

  echo "$filepath"

}

GetTempFile () {

  rand="1"
  tempfile='/tmp/'"$rand"

  while [ -f "$tempfile" ] ; do
    rand=$(echo "($rand * $$) % 10000" | bc)
    tempfile='/tmp/'"$rand"
  done

  touch "$tempfile" 2>/dev/null

  echo "$tempfile"
}



################################################################



apt install awscli

#trick from https://stackoverflow.com/questions/625644/find-out-the-instance-id-from-within-an-ec2-machine
#INST_ID=$(wget -q -O - http://169.254.169.254/latest/meta-data/instance-id)
INST_ID=$(wget -q -O - http://instance-data/latest/meta-data/instance-id)
AZ=$(wget -q -O - http://instance-data/latest/meta-data/placement/availability-zone)
REGION=$(echo "$AZ" | sed 's/^\([^0-9]*[0-9]\).*/\1/')

#IP setup
if [ -z "$IP" ] ; then
        #get the initial private ip
        IP=$(ip addr show eth0 | grep 'inet' | grep -v 'inet6' | tr -s ' ' | cut -d' ' -f3 | cut -d'/' -f1)
elif [ "$IP" = "assign" ] ; then

        #check if there is a free Elastic IP
        IP_FREE=""; IP_FREE=$(aws ec2 describe-addresses --region=eu-west-1 | tr '\n' ' ' | sed 's/Network/\
/g' | grep '}[^{]*{\([^"]*"\)\{12\}[^"]*}' | sed 's/[^{]*\({[^}]*}\).*/\1/' | tr ',' '\n' | grep PublicIp | cut -d'"' -f4)
        if [ -n "$IP_FREE" ] ; then

                aws ec2 associate-address --region="$REGION" --public-ip "$IP_FREE" --instance-id "$INST_ID"
                IP="$IP_FREE"

        else

                #if not, request a new one
                IP_FREE="$(aws ec2 allocate-address --region eu-west-1 | grep PublicIp | cut -d'"' -f4)"
                if [ -n "$IP_FREE" ] ; then
                        aws ec2 associate-address --region="$REGION" --public-ip "$IP_FREE" --instance-id "$INST_ID"
                        IP="$IP_FREE"
                fi
                #TODO: if request fails, return error and log the issue!
        fi

fi
##TODO: add last if branch - what if there was specific IP in $IP
##THIS IS NOT DONE YET
#elif echo "$IP" | grep '^\([0-9][0-9]*\.\)\{3\}[0-9][0-9]*$'
##        that can be used for testing, try to associate this specific IP if possible
#fi



#DNS Route53
SUBDOMAIN=$(echo "$DOMAIN" | rev | cut -d. -f3- | rev)
ROOTDOMAIN=$(echo "$DOMAIN" | rev | cut -d. -f1-2 | rev) #I expect this to be utdigit.com now

if [ "$DNS_CREATE" = "true" ] ; then
        if [ "$ROOTDOMAIN" = "utdigit.com" ] ; then
                echo ehe;
        fi
fi

USER='ubuntu'

#yarn: https://yarnpkg.com/lang/en/docs/install/#linux-tab

if [ "$JC" = "true" ] ; then
        curl --silent --show-error --header 'x-connect-key: 7d71eb7fbdbeeaa2bde0424f877cb5ce2ffe8e6b' https://kickstart.jumpcloud.com/Kickstart | sudo bash
fi

#toto zmenit? az podle prani Kofa
composer self-update 1.1.3

apt-get -y update
apt-get -y upgrade
apt-get -y autoremove

apt install unattended-upgrades


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
rm ./ISPC_update.exp


#find / -name phpmyadmin | xargs chgrp -R www-data
#find / -name phpmyadmin | xargs chmod -R g+w



#firewall
#ufw allow 22/tcp
#ufw allow 80/tcp
#ufw allow 443/tcp
#ufw allow 8080/tcp
#ufw enable
#ufw status



MYSQL_ROOTPW_DEFAULT='318250'
#change mySQL root PW
if [ -n "$MYSQL_ROOTPW" ] ; then
        echo "use dbispconfig; FLUSH PRIVILEGES; ALTER USER 'root'@'localhost' IDENTIFIED BY '$MYSQL_ROOTPW';" | mysql -u root -p"$MYSQL_ROOTPW_DEFAULT"
else
        MYSQL_ROOTPW="$MYSQL_ROOTPW_DEFAULT"
fi

#change ISPC admin password
echo "use dbispconfig; UPDATE sys_user SET passwort = md5('$ISPC_ADMINPW') WHERE username = 'admin' ;" | mysql -u root -p"$MYSQL_ROOTPW"



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
usermod -p "'$SSHPW_CRYPT'" webadmin

#this caused 502, but careful - be patient, server may sometimes need even 15-30 minutes to start and get to this phase
FPMCONF="/opt/php-7.1/etc/php-fpm.d/www.conf"
cat "$FPMCONF" | sed 's#^listen.*#listen = /var/lib/php7.0-fpm/ispconfig.sock#' > /tmp/temp; mv /tmp/temp "$FPMCONF"

systemctl stop    php-7.1-fpm
systemctl start   php7.0-fpm
systemctl restart nginx

#TODO: cleanup if needed
apt remove awscli
apt autoremove

rm /tmp/USERDATA_WORKING #just making sure here :D
#TODO: log file of this script?
touch /home/ubuntu/USERDATA_FINISHED 
reboot


