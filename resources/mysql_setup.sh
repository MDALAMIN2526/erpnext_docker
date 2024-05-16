#!/bin/bash

# Start the MariaDB service
systemctl start mariadb

# Use expect to automate mysql_secure_installation
expect <<EOF
spawn sudo mysql_secure_installation

expect "Enter current password for root (enter for none):"
send "\r"

expect "Set root password?"
send "y\r"

expect "New password:"
send "asdf@1234\r"

expect "Re-enter new password:"
send "asdf@1234\r"

expect "Remove anonymous users?"
send "y\r"

expect "Disallow root login remotely?"
send "y\r"

expect "Remove test database and access to it?"
send "y\r"

expect "Reload privilege tables now?"
send "y\r"

expect eof
EOF

# Stop the MariaDB service
systemctl restart mariadb
