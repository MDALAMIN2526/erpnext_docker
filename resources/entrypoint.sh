#!/bin/bash

# Start MariaDB service
service mariadb start

# Wait for MariaDB to be fully up and running
until mysqladmin ping -h 127.0.0.1 --silent; do
  echo 'Waiting for MariaDB to start...'
  sleep 2
done

# Set the root password for MariaDB
mysql -u root <<-EOSQL
  ALTER USER 'root'@'localhost' IDENTIFIED BY 'asdf@1234';
  FLUSH PRIVILEGES;
EOSQL

# Change to the frappe-bench directory
cd /home/cpmerp/frappe-bench

# Create a new site and set up ERPNext
bench new-site cpm.com --admin-password=asdf@1234 --db-root-password=asdf@1234 --install-app erpnext \
    && bench --site cpm.com enable-scheduler \
    && bench --site cpm.com set-maintenance-mode off \
    && bench setup production cpmerp \
    && bench setup nginx \
    && supervisorctl restart all

# Start Frappe Bench
exec bench serve --port 8000
