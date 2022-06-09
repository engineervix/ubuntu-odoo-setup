#!/usr/bin/env bash

# =================================================================================================
# description:  Installs Odoo on an Ubuntu server (tested with Odoo 15.0 on Ubuntu 20.04)
# author:       Victor Miti <https://github.com/engineervix>
# url:          <https://github.com/engineervix/ubuntu-odoo-setup>
# version:      0.1.0
# license:      MIT
#
# About this script
# ------------------------------ 
# This script builds on top of Yenthe Van Ginneken's excellent and well known Odoo Install Script
# <https://github.com/Yenthe666/InstallScript> to make it easy and painless to setup Odoo on a
# server bootstrapped using <https://github.com/engineervix/ubuntu-server-setup>
# 
# It can install multiple Odoo instances on one Ubuntu server because of the different xmlrpc_ports
# 
# 
# Usage
# ------
# - First things first, this script **assumes** that your Ubuntu server has been setup using
#   <https://github.com/engineervix/ubuntu-server-setup>. If this is the case ... proceed ...
# - download the script from GitHub:
#   wget https://github.com/engineervix/ubuntu-odoo-setup/raw/main/odoo_install.sh
# - make your own modifications if you wish to change some things
# - ensure that it's executable:
#   chmod +x odoo_install.sh
# - execute the script to install Odoo:
#   ./odoo-install.sh
# 
# How is this script different from Yenthe VG's ?
# ----------------------------------------------
# The main difference is that we already have a server that's been setup with a custom user,
# Nginx, certbot, PostgreSQL, Node.js, etc. So we don't wanna install these things. Further:
# - we'd like to use a virtual environment to run Odoo
# - we wanna use Systemd and not init
# 
# =================================================================================================

#--------------------------------------------------
# Preliminaries
#--------------------------------------------------

SCRIPT_DIR="$( cd "$(dirname "$0")" >/dev/null 2>&1 || exit ; pwd -P )"
timestamp=$(date '+%Y%m%d_%H%M%S')

function logTimestamp() {
  local filename=${1}
  {
    echo "===================" 
    echo "Log generated on $(date)"
    echo "==================="
  } >>"${filename}" 2>&1
}

read -rp "Please enter the name of your project (no spaces, no 'strange' characters):     " RAW_PROJECT_NAME
# ref: https://stackoverflow.com/questions/23816264/remove-all-special-characters-and-case-from-string-in-bash
PROJECT_NAME=$(echo "$RAW_PROJECT_NAME" | tr -dc '[:alnum:]\n\r' | tr '[:upper:]' '[:lower:]')
OE_USER="$USER"
OE_HOME="$HOME/projects/${PROJECT_NAME}"
OE_HOME_EXT="$OE_HOME/${PROJECT_NAME}-server"
# The default port where this Odoo instance will run under (provided you use the command -c in the terminal)
# Set the default Odoo port (you still have to use -c /etc/odoo-server.conf for example to use this.)
OE_PORT="8069"
# Choose the Odoo version which you want to install. For example: 13.0, 12.0, 11.0 or saas-18. When using 'master' the master version will be installed.
# IMPORTANT! This script contains extra libraries that are specifically needed for Odoo 15.0
OE_VERSION="15.0"
# Set this to True if you want to install the Odoo enterprise version!
IS_ENTERPRISE="True"
# Set this to True if you want to install Nginx OR you have it already installed you want the Nginx config automagically generated for you
INSTALL_NGINX="True"
# Set the superadmin password - if GENERATE_RANDOM_PASSWORD is set to "True" we will automatically generate a random password, otherwise we use this one
OE_SUPERADMIN="admin"
# Set to "True" to generate a random password, "False" to use the variable in OE_SUPERADMIN
GENERATE_RANDOM_PASSWORD="True"
OE_CONFIG="${PROJECT_NAME}-server"
# Set the website name
read -rp "Please enter the website name (e.g. sub.domain.com):     " WEBSITE_NAME
# Set the default Odoo longpolling port (you still have to use -c /etc/odoo-server.conf for example to use this.)
LONGPOLLING_PORT="8072"
# Set to "True" to install certbot and have ssl enabled, "False" to use http
ENABLE_SSL="True"
# Provide Email to register ssl certificate
read -rp "Please provide Email to register ssl certificate:     " ADMIN_EMAIL

output_file="${SCRIPT_DIR}/${PROJECT_NAME}_setup_output_${timestamp}.log"
echo -e "\e[35m===========================================================\e[00m" 
echo -e "\e[35mRunning setup script...\e[00m"
echo -e "\e[35m===========================================================\e[00m" 
logTimestamp "${output_file}"

# Use exec and tee to redirect logs to stdout and a log file at the same time 
# https://unix.stackexchange.com/a/145654
exec > >(tee -a "${output_file}") 2>&1

#--------------------------------------------------
# Install Dependencies
#--------------------------------------------------
echo -e "\n--- Installing some Python deps --"
sudo apt-get install python3-venv libxslt-dev libzip-dev libldap2-dev libsasl2-dev libtiff5-dev slapd ldap-utils lcov valgrind libpng-dev libpng++-dev gdebi-core -y

echo -e "\n---- Creating Virtual Environment ----"

export WORKON_HOME="${HOME}/Env"
export VIRTUALENVWRAPPER_PYTHON=/usr/bin/python3
# shellcheck source=/dev/null
source /usr/local/bin/virtualenvwrapper.sh

mkvirtualenv "${PROJECT_NAME}-odoo-server"

echo -e "\n---- Install python packages/requirements ----"
pip install wheel
pip install -r https://github.com/odoo/odoo/raw/${OE_VERSION}/requirements.txt

echo -e "\n---- Installing rtlcss for RTL support ----"
sudo npm install -g rtlcss

echo -e "\n---- Create Log directory ----"
sudo mkdir -p "/var/log/${OE_USER}"
sudo chown -R "${OE_USER}:${OE_USER}" "/var/log/${OE_USER}"

#--------------------------------------------------
# Install wkhtmltopdf
#--------------------------------------------------

# Apparently, the version of wkhtmltopdf that is included in Ubuntu repositories
# does not support headers and footers. The recommended version for Odoo
# is version 0.12.5. We’ll download and install the package from Github:

if [ "$(dpkg-query -W -f='${Status}' wkhtmltopdf 2>/dev/null | grep -c "ok installed")" -eq 1 ];
then
  # First remove any existing version of wkhtmltopdf:
  sudo apt-get remove wkhtmltopdf -y
fi
# Install from GitHub:
WKHTMLTOX_X64="https://github.com/wkhtmltopdf/wkhtmltopdf/releases/download/0.12.5/wkhtmltox_0.12.5-1.$(lsb_release -c -s)_amd64.deb"
wget "${WKHTMLTOX_X64}"
sudo gdebi --n "$(basename "${WKHTMLTOX_X64}")"
sudo ln -s /usr/local/bin/wkhtmltopdf /usr/bin
sudo ln -s /usr/local/bin/wkhtmltoimage /usr/bin

#--------------------------------------------------
# Install ODOO
#--------------------------------------------------
echo -e "\n==== Installing ODOO Server ===="
git clone --depth 1 --branch $OE_VERSION https://www.github.com/odoo/odoo "$OE_HOME_EXT"/

if [ $IS_ENTERPRISE = "True" ]; then
    # Odoo Enterprise install!
    pip install psycopg2-binary pdfminer.six
    mkdir -p "$OE_HOME/enterprise"
    mkdir -p "$OE_HOME/enterprise/addons"

    GITHUB_RESPONSE=$(git clone --depth 1 --branch $OE_VERSION https://www.github.com/odoo/enterprise "$OE_HOME/enterprise/addons" 2>&1)
    while [[ $GITHUB_RESPONSE == *"Authentication"* ]]; do
        echo "------------------------WARNING------------------------------"
        echo "Your authentication with Github has failed! Please try again."
        printf "In order to clone and install the Odoo enterprise version you \nneed to be an offical Odoo partner and you need access to\nhttp://github.com/odoo/enterprise.\n"
        echo "TIP: Press ctrl+c to stop this script."
        echo "-------------------------------------------------------------"
        echo " "
        GITHUB_RESPONSE=$(git clone --depth 1 --branch $OE_VERSION https://www.github.com/odoo/enterprise "$OE_HOME/enterprise/addons" 2>&1)
    done

    echo -e "\n---- Added Enterprise code under $OE_HOME/enterprise/addons ----"
    echo -e "\n---- Installing Enterprise specific libraries ----"
    pip install num2words ofxparse dbfread ebaysdk firebase_admin pyOpenSSL
    sudo npm install -g less
    sudo npm install -g less-plugin-clean-css
fi

echo -e "\n---- Create custom module directory ----"
mkdir -p "$OE_HOME/custom"
mkdir -p "$OE_HOME/custom/addons"

echo -e "* Create server config file"

sudo touch /etc/"${OE_CONFIG}".conf
echo -e "* Creating server config file"
sudo su root -c "printf '[options] \n; This is the password that allows database operations:\n' >> /etc/${OE_CONFIG}.conf"
if [ $GENERATE_RANDOM_PASSWORD = "True" ]; then
    echo -e "* Generating random admin password"
    # shellcheck disable=SC2002
    OE_SUPERADMIN=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 16 | head -n 1)
fi
sudo su root -c "printf 'admin_passwd = ${OE_SUPERADMIN}\n' >> /etc/${OE_CONFIG}.conf"
# shellcheck disable=SC2072
if [[ $OE_VERSION > "11.0" ]];then
    sudo su root -c "printf 'http_port = ${OE_PORT}\n' >> /etc/${OE_CONFIG}.conf"
else
    sudo su root -c "printf 'xmlrpc_port = ${OE_PORT}\n' >> /etc/${OE_CONFIG}.conf"
fi
sudo su root -c "printf 'logfile = /var/log/${OE_USER}/${OE_CONFIG}.log\n' >> /etc/${OE_CONFIG}.conf"

if [ $IS_ENTERPRISE = "True" ]; then
    sudo su root -c "printf 'addons_path=${OE_HOME}/enterprise/addons,${OE_HOME_EXT}/addons\n' >> /etc/${OE_CONFIG}.conf"
else
    sudo su root -c "printf 'addons_path=${OE_HOME_EXT}/addons,${OE_HOME}/custom/addons\n' >> /etc/${OE_CONFIG}.conf"
fi
sudo chown "$OE_USER:$OE_USER" /etc/"${OE_CONFIG}".conf
sudo chmod 640 /etc/"${OE_CONFIG}".conf

echo -e "* Create startup file"
echo "#!/usr/bin/env bash" >> "$OE_HOME_EXT/start.sh"
echo "$OE_HOME_EXT/odoo-bin --config=/etc/${OE_CONFIG}.conf" >> "$OE_HOME_EXT/start.sh"
chmod 755 "$OE_HOME_EXT"/start.sh

#--------------------------------------------------
# Setup PostgreSQL Database
#--------------------------------------------------
echo -e "\n---- Setup PostgreSQL Database ----"
db_name="${PROJECT_NAME}_db"
db_user="${PROJECT_NAME}_user"
db_password="${OE_SUPERADMIN}"
psql -c "CREATE USER ${db_user} PASSWORD '${db_password}'"
psql -c "CREATE DATABASE ${db_name} OWNER ${db_user}"
psql -c "GRANT ALL PRIVILEGES ON DATABASE ${db_name} to ${db_user}"

#--------------------------------------------------
# Adding the ODOO project as a daemon (Systemd)
#--------------------------------------------------

echo -e "* Create Systemd Service file"
cat <<EOF > ~/"$OE_CONFIG"
#!/usr/bin/env bash
[Unit]
Description=$OE_CONFIG
Requires=postgresql.service
After=network.target postgresql.service

[Service]
Type=simple
SyslogIdentifier=$OE_CONFIG
PermissionsStartOnly=true
User=$OE_USER
Group=$OE_USER
ExecStart=${HOME}/Env/${PROJECT_NAME}-odoo-server/bin/python3 ${OE_HOME_EXT}/odoo-bin -c /etc/${OE_CONFIG}.conf
StandardOutput=journal+console

[Install]
WantedBy=multi-user.target
EOF

echo -e "* Configure Systemd Service"
sudo mv -v ~/"$OE_CONFIG" /etc/systemd/system/"$OE_CONFIG".service
sudo chmod 755 /etc/systemd/system/"$OE_CONFIG".service
sudo chown root: /etc/systemd/system/"$OE_CONFIG".service

echo -e "* Start $OE_CONFIG on Startup"
sudo systemctl daemon-reload
sudo systemctl enable --now "$OE_CONFIG"

#--------------------------------------------------
# Install Nginx if needed
#--------------------------------------------------
if [ $INSTALL_NGINX = "True" ]; then
  echo -e "\n---- Installing and setting up Nginx ----"
  if [ "$(dpkg-query -W -f='${Status}' nginx 2>/dev/null | grep -c "ok installed")" -eq 0 ];
  then
    sudo apt install nginx -y;
  fi
  cat <<EOF > ~/odoo
server {
  listen 80;

  # set proper server name after domain set
  server_name $WEBSITE_NAME;

  # Add Headers for odoo proxy mode
  proxy_set_header X-Forwarded-Host \$host;
  proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
  proxy_set_header X-Forwarded-Proto \$scheme;
  proxy_set_header X-Real-IP \$remote_addr;
  add_header X-Frame-Options "SAMEORIGIN";
  add_header X-XSS-Protection "1; mode=block";
  proxy_set_header X-Client-IP \$remote_addr;
  proxy_set_header HTTP_X_FORWARDED_HOST \$remote_addr;

  #   odoo    log files
  access_log  /var/log/nginx/$OE_USER-access.log;
  error_log       /var/log/nginx/$OE_USER-error.log;

  #   increase    proxy   buffer  size
  proxy_buffers   16  64k;
  proxy_buffer_size   128k;

  proxy_read_timeout 900s;
  proxy_connect_timeout 900s;
  proxy_send_timeout 900s;

  #   force   timeouts    if  the backend dies
  proxy_next_upstream error   timeout invalid_header  http_500    http_502
  http_503;

  types {
    text/less less;
    text/scss scss;
  }

  #   enable  data    compression
  gzip    on;
  gzip_min_length 1100;
  gzip_buffers    4   32k;
  gzip_types  text/css text/less text/plain text/xml application/xml application/json application/javascript application/pdf image/jpeg image/png;
  gzip_vary   on;
  client_header_buffer_size 4k;
  large_client_header_buffers 4 64k;
  client_max_body_size 0;

  location / {
    proxy_pass    http://127.0.0.1:$OE_PORT;
    # by default, do not forward anything
    proxy_redirect off;
  }

  location /longpolling {
    proxy_pass http://127.0.0.1:$LONGPOLLING_PORT;
  }

  location ~* .(js|css|png|jpg|jpeg|gif|ico)$ {
    expires 2d;
    proxy_pass http://127.0.0.1:$OE_PORT;
    add_header Cache-Control "public, no-transform";
  }

  # cache some static data in memory for 60mins.
  location ~ /[a-zA-Z0-9_-]*/static/ {
    proxy_cache_valid 200 302 60m;
    proxy_cache_valid 404      1m;
    proxy_buffering    on;
    expires 864000;
    proxy_pass    http://127.0.0.1:$OE_PORT;
  }
}
EOF

  sudo mv -v ~/odoo /etc/nginx/sites-available/"$WEBSITE_NAME"
  sudo ln -s /etc/nginx/sites-available/"$WEBSITE_NAME" /etc/nginx/sites-enabled/"$WEBSITE_NAME"
  sudo rm -v /etc/nginx/sites-enabled/default
  sudo systemctl reload nginx
  sudo su root -c "printf 'proxy_mode = True\n' >> /etc/${OE_CONFIG}.conf"
  echo "Done! The Nginx server is up and running. Configuration can be found at /etc/nginx/sites-available/$WEBSITE_NAME"
else
  echo "Nginx isn't installed due to choice of the user!"
fi

#--------------------------------------------------
# Enable ssl with certbot
#--------------------------------------------------

if [ $INSTALL_NGINX = "True" ] && [ $ENABLE_SSL = "True" ] && [ "$ADMIN_EMAIL" != "odoo@example.com" ]  && [ "$WEBSITE_NAME" != "_" ];then
  #sudo add-apt-repository ppa:certbot/certbot -y && sudo apt-get update -y
  #sudo apt-get install python3-certbot-nginx -y
  sudo certbot --nginx -d "$WEBSITE_NAME" --noninteractive --agree-tos --email "$ADMIN_EMAIL" --redirect
  sudo systemctl reload nginx
  echo "SSL/HTTPS is enabled!"
else
  echo "SSL/HTTPS isn't enabled due to choice of the user or because of a misconfiguration!"
fi

#--------------------------------------------------
# And we're done!
#--------------------------------------------------

echo "-----------------------------------------------------------"
echo "Done! The $OE_CONFIG project should be up and running. Specifications:"
echo "Port: $OE_PORT"
echo "User: $OE_USER"
echo "Configuraton file location: /etc/${OE_CONFIG}.conf"
echo "Logfile location: /var/log/$OE_USER"
echo "PostgreSQL User: $db_user"
echo "PostgreSQL Database: $db_name"
echo "Password superadmin (database): $OE_SUPERADMIN"
echo "Code location: $OE_HOME"
echo "Addons folder: $OE_HOME_EXT/addons/"
echo "Start $OE_CONFIG service: sudo systemctl start $OE_CONFIG"
echo "Stop $OE_CONFIG service: sudo systemctl stop $OE_CONFIG"
echo "Restart $OE_CONFIG service: sudo systemctl restart $OE_CONFIG"
echo "Check Status of $OE_CONFIG service: sudo systemctl status $OE_CONFIG"
if [ $INSTALL_NGINX = "True" ]; then
  echo "Nginx configuration file: /etc/nginx/sites-available/$WEBSITE_NAME"
fi
echo "-----------------------------------------------------------"
