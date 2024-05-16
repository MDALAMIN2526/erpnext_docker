# Start from a base image
FROM ubuntu:22.04

# Install necessary packages
RUN apt-get update && \
    apt-get install -y \
    git \
    sudo \
    cron \
    curl \
    python3 \
    python3-dev \
    python3-setuptools \
    python3-pip \
    virtualenv \
    software-properties-common \
    mariadb-server \
    libmysqlclient-dev \
    redis-server \
    xvfb \
    libfontconfig \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Install Node.js using NVM
RUN curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.1/install.sh | bash && \
    export NVM_DIR="$HOME/.nvm" && \
    [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh" && \
    nvm install 18.18.2 && \
    npm install -g npm@latest && \
    npm install -g yarn

# Copy MariaDB configuration file
COPY resources/50-server.cnf /etc/mysql/mariadb.conf.d/50-server.cnf

# Copy MySQL setup script
COPY resources/mysql_setup.sh /usr/local/bin/mysql_setup.sh

# Make the script executable
RUN chmod +x /usr/local/bin/mysql_setup.sh

# Start MariaDB service and run setup script
RUN service mariadb start && \
    /usr/local/bin/mysql_setup.sh && \
    service mariadb stop

# Create a new user
RUN adduser cpmerp && \
    usermod -aG sudo cpmerp && \
    su - cpmerp -c "chmod -R o+rx /home/cpmerp"

# Install frappe-bench
RUN sudo pip3 install --user frappe-bench 
RUN su - cpmerp -c "bench init --frappe-branch version-15 frappe-bench"
RUN su - cpmerp -c "cd frappe-bench && bench start" && \
    su - cpmerp -c "bench new-site cpm.com && bench use cpm.com" && \
    su - cpmerp -c "bench get-app https://github.com/frappe/erpnext --branch version-15 && bench --site cpm.com install-app erpnext && bench start"

# Setup production server
RUN su - cpmerp -c "bench --site cpm.com enable-scheduler" && \
    su - cpmerp -c "bench --site cpm.com set-maintenance-mode off" && \
    su - cpmerp -c "sudo bench setup production cpmerp && bench setup nginx && sudo supervisorctl restart all && sudo bench setup production cpmerp"
# Expose ports
EXPOSE 80/tcp
EXPOSE 3306
# Default command
CMD ["bash", "-c", "/home/cpmerp/frappe-bench"]
