FROM ubuntu:22.04

# Set environment variables
ENV NODE_VERSION=18.18.2
ENV NVM_DIR=/usr/local/nvm
ENV PATH=$NVM_DIR/versions/node/v$NODE_VERSION/bin:$PATH

# Create a new user
RUN adduser --disabled-password --gecos '' cpmerp \
    && usermod -aG sudo cpmerp

# Create NVM directory
RUN mkdir -p $NVM_DIR

# Install necessary packages and Node.js, Yarn
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
    python3.10-venv && \
    apt-get clean && rm -rf /var/lib/apt/lists/* && \
    curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.1/install.sh | bash && \
    . $NVM_DIR/nvm.sh && \
    nvm install $NODE_VERSION && \
    nvm use $NODE_VERSION && \
    nvm alias default $NODE_VERSION && \
    npm install -g yarn

# Copy MariaDB configuration file
COPY resources/50-server.cnf /etc/mysql/mariadb.conf.d/50-server.cnf

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

# Switch back to root to start MariaDB
USER root

# Copy and make the entrypoint script executable
COPY resources/entrypoint.sh /usr/local/bin/
RUN chmod +x /usr/local/bin/entrypoint.sh

# Expose ports
EXPOSE 80/tcp
EXPOSE 3306

# Healthcheck to ensure services are running
HEALTHCHECK --interval=30s --timeout=10s \
  CMD curl -f http://localhost:8000/health || exit 1

# Use entrypoint script
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
