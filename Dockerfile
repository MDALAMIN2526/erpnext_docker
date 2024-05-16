# keep the command septs as it is, correct the command. 
FROM ubuntu:22.04

# STEP 1 Install git, cron, and curl
RUN apt-get update && \
    apt-get install -y git cron curl

# STEP 2 Install python-dev
RUN apt-get install -y python3-dev

# STEP 3 Install setuptools and pip
RUN apt-get install -y python3-setuptools python3-pip

# STEP 4 Install virtualenv
RUN apt-get install -y virtualenv

# CHECK PYTHON VERSION
RUN python3 -V

# Install python3.8-venv or python3.10-venv based on python version
RUN if python3 -V 2>&1 | grep -q '3.8'; then \
        apt-get install -y python3.8-venv; \
    elif python3 -V 2>&1 | grep -q '3.10'; then \
        apt-get install -y python3.10-venv; \
    fi

# STEP 5 Install MariaDB
RUN apt-get install -y software-properties-common && \
    apt-get install -y mariadb-server && \
    apt-get install -y libmysqlclient-dev
# Copy MySQL setup script
COPY resources/mysql_setup.sh /usr/local/bin/mysql_setup.sh

# Make the script executable
RUN chmod +x /usr/local/bin/mysql_setup.sh

# Run the setup script
RUN /usr/local/bin/mysql_setup.sh

# STEP 6 Install Redis
RUN apt-get install -y redis-server

# STEP 7 Edit the mariadb configuration ( unicode character encoding )
COPY resources/50-server.cnf /etc/mysql/mariadb.conf.d/50-server.cnf

# STEP 8 Install Node.js 14.X package
RUN curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.1/install.sh | bash && \
    export NVM_DIR="$HOME/.nvm" && \
    [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh" && \
    nvm install 14 && \
    nvm use 14 && \
    nvm alias default 14

# STEP 9 Install Yarn
RUN apt-get install -y npm && \
    npm install -g yarn

# STEP 10 Install wkhtmltopdf
RUN apt-get install -y xvfb libfontconfig wkhtmltopdf

# STEP 11 Create a new user
RUN adduser cpmerp && \
    usermod -aG sudo cpmerp && \
    su - cpmerp -c "chmod -R o+rx /home/cpmerp"

# STEP 12 Install frappe-bench
RUN sudo -H pip3 install frappe-bench && \
    su - cpmerp -c "bench init --frappe-branch version-15 frappe-bench" && \
    su - cpmerp -c "cd frappe-bench && bench start" && \
    su - cpmerp -c "bench new-site cpm.com && bench use cpm.com" && \
    su - cpmerp -c "bench get-app https://github.com/frappe/erpnext --branch version-15 && bench --site cpm.com install-app erpnext && bench start"

# STEP 13 SETUP PRODUCTION SERVER
RUN su - cpmerp -c "bench --site cpm.com enable-scheduler" && \
    su - cpmerp -c "bench --site cpm.com set-maintenance-mode off" && \
    su - cpmerp -c "sudo bench setup production cpmerp && bench setup nginx && sudo supervisorctl restart all && sudo bench setup production cpmerp"

# Expose ports if needed
EXPOSE 80/tcp
# Expose MySQL port
EXPOSE 3306

# Define default command
CMD ["bash", "-c", "/home/cpmerp/frappe-bench"]
