# Installation Instructions

```sh
# Install MySQL Server
sudo apt update
sudo apt install -y mysql-server
sudo systemctl start mysql.service

# Initialize Database
sudo mysql
CREATE DATABASE ya_seo_schedules;
CREATE USER 'ya_seo_schedules_user'@'localhost' IDENTIFIED BY '123456aA@';
FLUSH PRIVILEGES;
GRANT ALL PRIVILEGES ON * . * TO 'ya_seo_schedules_user'@'localhost';
ALTER USER 'ya_seo_schedules_user'@'localhost' IDENTIFIED BY '123456aA@';
FLUSH PRIVILEGES;
exit;

# Install PHP 8.1
sudo apt update
sudo apt install -y lsb-release ca-certificates apt-transport-https software-properties-common
sudo add-apt-repository -y ppa:ondrej/php
sudo apt update
sudo apt install -y php8.1
sudo apt install -y php8.1-{bcmath,xml,fpm,mysql,zip,intl,ldap,gd,cli,bz2,curl,mbstring,pgsql,opcache,soap,cgi}
php --version
php --modules

# Install Composer
sudo apt update
sudo apt install -y unzip
curl -sS https://getcomposer.org/installer -o /tmp/composer-setup.php
HASH=`curl -sS https://composer.github.io/installer.sig`
php -r "if (hash_file('SHA384', '/tmp/composer-setup.php') === '$HASH') { echo 'Installer verified'; } else { echo 'Installer corrupt'; unlink('composer-setup.php'); } echo PHP_EOL;"
sudo php /tmp/composer-setup.php --install-dir=/usr/local/bin --filename=composer
export COMPOSER_ALLOW_SUPERUSER=1; composer --version;

# Install Java
sudo apt update
sudo apt install -y default-jre
sudo apt install -y default-jdk
java -version

# Install Jenkins
sudo apt update
#curl -fsSL https://pkg.jenkins.io/debian-stable/jenkins.io.key | sudo tee /usr/share/keyrings/jenkins-keyring.asc > /dev/null
#echo deb [signed-by=/usr/share/keyrings/jenkins-keyring.asc] https://pkg.jenkins.io/debian-stable binary/ | sudo tee /etc/apt/sources.list.d/jenkins.list > /dev/null
curl -fsSL https://pkg.jenkins.io/debian-stable/jenkins.io-2023.key | sudo tee \
  /usr/share/keyrings/jenkins-keyring.asc > /dev/null
echo deb [signed-by=/usr/share/keyrings/jenkins-keyring.asc] \
  https://pkg.jenkins.io/debian-stable binary/ | sudo tee \
  /etc/apt/sources.list.d/jenkins.list > /dev/null
sudo apt-get update
sudo apt-get -y install jenkins

# Install npm
sudo apt update
cd ~
curl -sL https://deb.nodesource.com/setup_16.x | sudo bash -
sudo apt -y install nodejs
node -v

# Switch PHP Version
# Switch to PHP 8.1
sudo a2dismod php7.4
sudo a2enmod php8.1
sudo service apache2 restart
sudo update-alternatives --set php /usr/bin/php8.1

# Switch to PHP 7.4
sudo a2dismod php8.1
sudo a2enmod php7.4
sudo service apache2 restart
sudo update-alternatives --set php /usr/bin/php7.4

# Configure Apache2
mkdir /var/lib/jenkins/
mkdir /var/lib/jenkins/workspace
cd  /var/lib/jenkins/workspace
git clone https://thanhnv996:glpat-xxxx@gitlab.com/thanhnv996/ya-seo-schedules.git

sudo apt update
sudo apt install apache2

nano /etc/apache2/sites-available/ya-seo-schedules.conf
<VirtualHost *:80>
        #ServerName tools.hitmakers.vip
        #ServerAlias www.tools.hitmakers.vip

        DocumentRoot /var/lib/jenkins/workspace/ya-seo-schedules/public

        ErrorLog ${APACHE_LOG_DIR}/error.log
        CustomLog ${APACHE_LOG_DIR}/access.log combined

        <Directory /var/lib/jenkins/workspace/ya-seo-schedules/public>
                Options Indexes FollowSymLinks
                AllowOverride all
                Require all granted
        </Directory>
</VirtualHost>

cd /etc/apache2/sites-available/
a2dissite 000-default.conf
sudo a2ensite ya-seo-schedules.conf
sudo a2enmod rewrite
systemctl reload apache2

cd /var/lib/jenkins/workspace/ya-seo-schedules
cp .env.example .env
composer i
php artisan key:generate
chown -R $USER:www-data storage
chmod -R 775 storage
chmod -R 775 bootstrap/cache
chown -R jenkins:jenkins storage
