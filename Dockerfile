FROM ubuntu:22.04

# Set environment variables
ENV NODE_VERSION 18.18.2

# Create a new user
RUN adduser --disabled-password --gecos '' cpmerp \
    && usermod -aG sudo cpmerp

# Install necessary packages
RUN apt-get update && \
    DEBIAN_FRONTEND=noninteractive apt-get install -y \
    git \
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
    python3.10-venv \
    npm \
    && apt-get clean && rm -rf /var/lib/apt/lists/*
# Install NVM, Node.js, and Yarn
RUN DEBIAN_FRONTEND=noninteractive apt-get remove -y \
    nodejs \
    npm
RUN apt-get update && apt-get autoremove
RUN curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.1/install.sh | bash && \
    export NVM_DIR="$HOME/.nvm" && \
    [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh" && \
    nvm install 18.18.2 && \
    nvm use 18.18.2 && \
    nvm alias default 18.18.2 && 
RUN  npm install npm
RUN  npm install -y -g yarn
# Copy MariaDB configuration file and setup script
COPY resources/50-server.cnf /etc/mysql/mariadb.conf.d/50-server.cnf
COPY resources/mysql_setup.sh /usr/local/bin/mysql_setup.sh

# Make the script executable
RUN chmod +x /usr/local/bin/mysql_setup.sh

# Switch user and set permissions
USER cpmerp
WORKDIR /home/cpmerp
# Install Frappe Bench
RUN pip3 install frappe-bench

# Initialize Frappe Bench
ENV PATH="/home/cpmerp/.local/bin:${PATH}"
RUN bench init --frappe-branch version-15 frappe-bench
WORKDIR /home/cpmerp
RUN bench get-app https://github.com/frappe/erpnext --branch version-15 \
    && bench new-site cpm.com --admin-password=asdf@1234 --root-password=asdf@1234 --install-app erpnext \
    && bench --site cpm.com enable-scheduler \
    && bench --site cpm.com set-maintenance-mode off \
    && bench setup production cpmerp \
    && bench setup nginx \
    && supervisorctl restart all

# Expose ports
EXPOSE 80/tcp
EXPOSE 3306

# Start Frappe Bench
CMD ["bench", "serve", "--port", "8000"]
