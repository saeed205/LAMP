#!/bin/bash

# Check if running as root
if [ "$(id -u)" -ne "0" ]; then
  echo "This script must be run as root" 1>&2
  exit 1
fi

# Update package repositories
apt update

# Upgrade installed packages
apt upgrade -y

# Install Apache, MariaDB, and PHP
apt install -y apache2 apache2-utils mariadb-server mariadb-client php libapache2-mod-php php-mysql php-common php-cli php-json php-opcache php-readline php-mbstring php-gd php-dom php-zip php-curl php8.2-fpm

# Start and enable Apache
systemctl start apache2
systemctl enable apache2

# Start and enable MariaDB
systemctl start mariadb
systemctl enable mariadb

# Secure MariaDB installation
mysql_secure_installation

# Create MySQL database and user for WordPress
read -s -p "Enter MariaDB root password: " db_root_password
echo
read -p "Enter WordPress database name: " wordpress_db
read -p "Enter WordPress database user: " wordpress_user
read -s -p "Enter WordPress database password: " wordpress_password
echo

mysql -u root -p$db_root_password <<MYSQL_SCRIPT
CREATE DATABASE $wordpress_db;
CREATE USER '$wordpress_user'@'localhost' IDENTIFIED BY '$wordpress_password';
GRANT ALL PRIVILEGES ON $wordpress_db.* to '$wordpress_user'@'localhost';
FLUSH PRIVILEGES;
exit
MYSQL_SCRIPT

# Display MySQL database user and password information
echo "WordPress database name: $wordpress_db"
echo "WordPress database user: $wordpress_user"
echo "WordPress database password: $wordpress_password"

# Download and extract WordPress
wget -O /tmp/wordpress.tar.gz https://wordpress.org/latest.tar.gz
tar -xzvf /tmp/wordpress.tar.gz -C /var/www/html
chown -R www-data:www-data /var/www/html

# Move WordPress files to the root directory
mv /var/www/html/wordpress/* /var/www/html/
rm -rf /var/www/html/wordpress
rm /var/www/html/index.html

# Set permissions for wp-config.php file
chmod 660 /var/www/html/wp-config-sample.php
chmod 660 /var/www/html/wp-config.php

# Configure Apache to serve WordPress from the root address
sed -i 's/\/var\/www\/html/\/var\/www\/html/g' /etc/apache2/sites-available/000-default.conf

# Enable the necessary modules
a2enmod rewrite
a2enmod php8.2
a2enmod proxy_fcgi setenvif
a2enconf php8.2-fpm

# Restart Apache
systemctl restart apache2

# Clean up temporary files
rm /tmp/wordpress.tar.gz

# Get server IP address or domain
server_ip=$(hostname -I | awk '{print $1}')

echo "WordPress setup complete. You can now access your site at http://$server_ip/"
