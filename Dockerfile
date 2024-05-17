FROM ubuntu:22.04

# Install required packages
RUN apt-get update && \
    DEBIAN_FRONTEND=noninteractive apt-get install -y \
    sudo \
    git \
    cron \
    curl \
    python3 \
    python3-dev \
    python3-setuptools \
    python3-pip \
    virtualenv \
    software-properties-common \
    libmysqlclient-dev \
    redis-server \
    xvfb \
    libfontconfig \
    python3.10-venv && \
    apt-get clean && rm -rf /var/lib/apt/lists/* 

# Create a new user
RUN adduser --disabled-password --gecos '' cpmerp \
    && usermod -aG sudo cpmerp

# Environment variables
ENV NODE_VERSION=18.18.2
ENV NVM_DIR=/usr/local/nvm
ENV PATH=$NVM_DIR/versions/node/v$NODE_VERSION/bin:$PATH

# Create necessary directories and install Node.js using nvm
RUN mkdir -p $NVM_DIR
RUN curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.1/install.sh | bash && \
    . $NVM_DIR/nvm.sh && \
    nvm install $NODE_VERSION && \
    nvm use $NODE_VERSION && \
    nvm alias default $NODE_VERSION && \
    npm install -g yarn

# Set the working directory
WORKDIR /home/cpmerp
RUN python3 -m pip install --upgrade pip
# Install Frappe Bench
RUN pip3 install frappe-bench
RUN python3 -m pip install --user --upgrade pip setuptools wheel && \
    python3 -m pip install --user bench

# Switch to the cpmerp user
USER cpmerp

# Update PATH for the cpmerp user
ENV PATH="/home/cpmerp/.local/bin:${PATH}"

# Initialize bench and get erpnext app
RUN bench init --frappe-branch version-15 frappe-bench
WORKDIR /home/cpmerp/frappe-bench
RUN bench get-app erpnext --branch version-15

# Load environment variables from .env file
COPY .env /home/cpmerp/frappe-bench/.env
RUN pip install python-dotenv

# Create site using environment variables
RUN python3 -c "import os; from dotenv import load_dotenv; load_dotenv(); \
    os.system(f'bench new-site {os.getenv('SITE_NAME')} \
    --admin-password={os.getenv('DB_ROOT_PASSWORD')} \
    --mariadb-root-username={os.getenv('DB_ROOT_USER')} \
    --mariadb-root-password={os.getenv('DB_ROOT_PASSWORD')} \
    --db-host={os.getenv('DB_HOST')} \
    --install-app erpnext && \
    bench --site {os.getenv('SITE_NAME')} enable-scheduler && \
    bench --site {os.getenv('SITE_NAME')} set-maintenance-mode off')"

# Switch back to root user to set up production and restart services
USER root
RUN bench setup production cpmerp && \
    bench setup nginx && \
    service supervisor restart

# Switch back to cpmerp user
USER cpmerp
RUN bench get-app erpnext --branch version-15

# Expose necessary ports
EXPOSE 80/tcp
EXPOSE 3306

# Healthcheck
HEALTHCHECK --interval=30s --timeout=10s \
  CMD curl -f http://localhost:8000/health || exit 1

# Default command
CMD ["bench", "serve", "--port", "8000"]
