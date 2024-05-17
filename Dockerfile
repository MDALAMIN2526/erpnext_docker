FROM ubuntu:22.04

# Set environment variables
ENV NODE_VERSION=18.18.2
ENV NVM_DIR=/usr/local/nvm
ENV PATH=$NVM_DIR/versions/node/v$NODE_VERSION/bin:$PATH

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
    && apt-get clean && rm -rf /var/lib/apt/lists/*

# Install NVM, Node.js, and Yarn
RUN mkdir -p $NVM_DIR && \
    curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.1/install.sh | bash && \
    . $NVM_DIR/nvm.sh && \
    nvm install $NODE_VERSION && \
    nvm use $NODE_VERSION && \
    nvm alias default $NODE_VERSION && \
    npm install -g yarn

# Copy MariaDB configuration file and setup script
COPY resources/50-server.cnf /etc/mysql/mariadb.conf.d/50-server.cnf
COPY resources/mysql_setup.sh /usr/local/bin/mysql_setup.sh

# Make the script executable
RUN chmod +x /usr/local/bin/mysql_setup.sh

# Set working directory
WORKDIR /home/cpmerp

# Install Frappe Bench
RUN pip3 install frappe-bench

# Change user to cpmerp
USER cpmerp

# Set PATH for the new user
ENV PATH="/home/cpmerp/.local/bin:${PATH}"

# Initialize Frappe Bench
RUN bench init --frappe-branch version-15 frappe-bench
WORKDIR /home/cpmerp/frappe-bench
RUN bench get-app https://github.com/frappe/erpnext --branch version-15
RUN bench new-site cpm.com --admin-password=asdf@1234 --db-root-password=asdf@1234 --install-app erpnext \
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
