FROM ubuntu:22.04
ENV NODE_VERSION=18.18.2
ENV NVM_DIR=/usr/local/nvm
ENV PATH=$NVM_DIR/versions/node/v$NODE_VERSION/bin:$PATH
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
    mariadb-server \
    libmysqlclient-dev \
    redis-server \
    xvfb \
    libfontconfig \
    python3.10-venv && \
    apt-get clean && rm -rf /var/lib/apt/lists/* 
RUN mkdir -p $NVM_DIR
RUN curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.1/install.sh | bash && \
    . $NVM_DIR/nvm.sh && \
    nvm install $NODE_VERSION && \
    nvm use $NODE_VERSION && \
    nvm alias default $NODE_VERSION && \
    npm install -g yarn

RUN adduser --disabled-password --gecos '' cpmerp \
    && usermod -aG sudo cpmerp
RUN service mariadb restart
RUN if ! pgrep mariadb > /dev/null; then \
      service mariadb start && \
      until mysqladmin ping -h 127.0.0.1 --silent; do \
        echo 'Waiting for MariaDB to start...'; \
        sleep 2; \
      done; \
    fi && \
    mysql -u root -e "ALTER USER 'root'@'localhost' IDENTIFIED BY 'asdf@1234'; FLUSH PRIVILEGES;"
WORKDIR /home/cpmerp
RUN pip3 install frappe-bench
RUN python3 -m pip install --user --upgrade pip setuptools wheel && \
    python3 -m pip install --user bench
USER cpmerp
ENV PATH="/home/cpmerp/.local/bin:${PATH}"
RUN bench init --frappe-branch version-15 frappe-bench
WORKDIR /home/cpmerp/frappe-bench
RUN bench get-app erpnext --branch version-15
USER root
RUN service mariadb start && \
    until mysqladmin ping -h 127.0.0.1 --silent; do \
        echo 'Waiting for MariaDB to start...'; \
        sleep 2; \
    done
RUN service mariadb status
USER cpmerp
RUN bench new-site cpm.com --admin-password=asdf@1234 --db-root-password=asdf@1234 --install-app erpnext && \
    bench --site cpm.com enable-scheduler && \
    bench --site cpm.com set-maintenance-mode off
USER root
RUN bench setup production cpmerp && \
    bench setup nginx && \
    service supervisor restart
USER cpmerp
RUN bench get-app erpnext --branch version-15
EXPOSE 80/tcp
EXPOSE 3306
HEALTHCHECK --interval=30s --timeout=10s \
  CMD curl -f http://localhost:8000/health || exit 1
CMD ["bench", "serve", "--port", "8000"]
