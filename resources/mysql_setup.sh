#!/bin/bash

# Start the MariaDB service
service mariadb start

# Run mysql_secure_installation non-interactively
mysql -u root -e "ALTER USER 'root'@'localhost' IDENTIFIED WITH mysql_native_password BY 'asdf@1234'; FLUSH PRIVILEGES;"

# Additional MySQL configuration if needed
# For example:
# mysql -u root -p<your_password> -e "ALTER USER 'root'@'localhost' IDENTIFIED WITH mysql_native_password BY 'your_password'; FLUSH PRIVILEGES;"

# Stop the MariaDB service
service mariadb stop
