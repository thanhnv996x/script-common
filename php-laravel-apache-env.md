[//]: # (install php 8.1)
sudo apt update
sudo apt install -y mysql-server
sudo systemctl start mysql.service

[//]: # (install php 8.1)
sudo apt update
sudo apt install -y lsb-release ca-certificates apt-transport-https software-properties-common -y
sudo add-apt-repository -y ppa:ondrej/php
sudo apt update
sudo apt install -y php8.1
sudo apt install -y php8.1-{bcmath,xml,fpm,mysql,zip,intl,ldap,gd,cli,bz2,curl,mbstring,pgsql,opcache,soap,cgi}
php --version
php --modules

[//]: # (install composer)
sudo apt update
sudo apt install -y unzip
curl -sS https://getcomposer.org/installer -o /tmp/composer-setup.php
HASH=`curl -sS https://composer.github.io/installer.sig`
php -r "if (hash_file('SHA384', '/tmp/composer-setup.php') === '$HASH') { echo 'Installer verified'; } else { echo 'Installer corrupt'; unlink('composer-setup.php'); } echo PHP_EOL;"
sudo php /tmp/composer-setup.php --install-dir=/usr/local/bin --filename=composer
composer

[//]: # (install java )
sudo apt update
sudo apt install -y default-jre
sudo apt install -y default-jdk
java -version

[//]: # (install jenkin )
sudo apt update
curl -fsSL https://pkg.jenkins.io/debian-stable/jenkins.io.key | sudo tee \
/usr/share/keyrings/jenkins-keyring.asc > /dev/null
echo deb [signed-by=/usr/share/keyrings/jenkins-keyring.asc] \
https://pkg.jenkins.io/debian-stable binary/ | sudo tee \
/etc/apt/sources.list.d/jenkins.list > /dev/null
sudo apt-get update
sudo apt-get -y install jenkins

[//]: # (install npm)
sudo apt update
cd ~
curl -sL https://deb.nodesource.com/setup_16.x | sudo bash -
sudo apt -y install nodejs
node  -v

[//]: # (init db)
sudo mysql
CREATE DATABASE ya_seo_schedules;
CREATE USER 'ya_seo_schedules_user'@'localhost' IDENTIFIED BY '123456aA@';
FLUSH PRIVILEGES;
GRANT ALL PRIVILEGES ON * . * TO 'ya_seo_schedules_user'@'localhost';
exit;

ALTER USER 'ya_seo_schedules_user'@'localhost' IDENTIFIED BY '123456aA@';
FLUSH PRIVILEGES;

[//]: # (install php 8.1)
sudo apt update
sudo apt install lsb-release ca-certificates apt-transport-https software-properties-common -y
sudo add-apt-repository ppa:ondrej/php
sudo apt update
sudo apt install php8.1
sudo apt install php8.1-{bcmath,xml,fpm,mysql,zip,intl,ldap,gd,cli,bz2,curl,mbstring,pgsql,opcache,soap,cgi}
php --version
php --modules


[//]: # (switch php version)
sudo update-alternatives --config php

[//]: # (switch php version 8.1)
sudo a2dismod php7.4
sudo a2enmod php8.1
sudo service apache2 restart
sudo update-alternatives --set php /usr/bin/php8.1

[//]: # (switch php version 7.4)
sudo a2dismod php8.1
sudo a2enmod php7.4
sudo service apache2 restart
sudo update-alternatives --set php /usr/bin/php7.4

[//]: # (config apache2)
sudo a2ensite ya-console.local
systemctl reload apache2

chown -R $USER:www-data storage
chmod -R 775 storage
chmod -R 775 bootstrap/cache
chown -R jenkins:jenkins storage
