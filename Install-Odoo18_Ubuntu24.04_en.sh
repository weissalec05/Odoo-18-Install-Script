#!/bin/bash

#Variables for Installation
ODOO_USER="odoo18" #Odoo user is also database user
DB_PASSWORD=""
MASTER_PASSWORD="" #This is the password that allows database operations

if [[ -z "$ODOO_USER" || -z "$DB_PASSWORD" || -z "$MASTER_PASSWORD" ]]; then
    echo "------------------------------------------------------------------------"
    echo "❌ One or more required variables (ODOO_USER, DB_PASSWORD, MASTER_PASSWORD) are not set."
    echo "💡 Please set all variables before running the script."
    echo "------------------------------------------------------------------------"
    exit 1
fi

echo "------------------------------------------------------------------------"
echo "🔄 Updating Server and installing required packages..."
echo "------------------------------------------------------------------------"
sleep 5s
sudo apt-get update && sudo apt-get upgrade -y 
sudo apt-get install -y libpq-dev
sudo apt-get install -y openssh-server
sudo apt-get install -y git
sudo apt-get install -y fail2ban
sudo apt-get install -y python3-pip
sudo apt-get install -y python3-dev libxml2-dev libxslt1-dev zlib1g-dev libsasl2-dev libldap2-dev build-essential libssl-dev libffi-dev libmysqlclient-dev libjpeg-dev libpq-dev libjpeg8-dev liblcms2-dev libblas-dev libatlas-base-dev
sudo apt-get install -y npm && sudo ln -s /usr/bin/nodejs /usr/bin/node
sudo apt install -y python3-venv
sudo npm install -g less less-plugin-clean-css
sudo apt-get install -y node-less

echo "------------------------------------------------------------------------"
echo "🛡️ Starting and enabling fail2ban"
echo "------------------------------------------------------------------------"
sleep 5s
sudo systemctl start fail2ban
sudo systemctl enable fail2ban

echo "------------------------------------------------------------------------"
echo "🗂️ Setting up PostgreSQL database and user"
echo "------------------------------------------------------------------------"
sleep 5s
sudo apt-get install -y postgresql
sleep 1s
sudo -u postgres psql -c "CREATE ROLE odoo18 WITH CREATEDB SUPERUSER LOGIN PASSWORD '${DB_PASSWORD}';"

echo "------------------------------------------------------------------------"
echo "🙍 Creating Odoo system user"
echo "------------------------------------------------------------------------"
sleep 5s
sudo adduser --system --home=/opt/${ODOO_USER} --group ${ODOO_USER}

echo "------------------------------------------------------------------------"
echo "📥 Downloading & installing Odoo18 from Github"
echo "------------------------------------------------------------------------"
sleep 5s
sudo rm -rf /opt/${ODOO_USER}
git clone https://github.com/odoo/odoo --depth 1 --branch 18.0 --single-branch /opt/${ODOO_USER}

echo "------------------------------------------------------------------------"
echo "🛠️ Creating a Python virtual environment & installing dependencies"
echo "------------------------------------------------------------------------"
sleep 3s

sudo python3 -m venv /opt/${ODOO_USER}/venv

(
  source /opt/${ODOO_USER}/venv/bin/activate

  pip install -r /opt/${ODOO_USER}/requirements.txt

  sudo wget https://github.com/wkhtmltopdf/wkhtmltopdf/releases/download/0.12.5/wkhtmltox_0.12.5-1.bionic_amd64.deb -P /tmp
  sudo wget http://archive.ubuntu.com/ubuntu/pool/main/o/openssl/libssl1.1_1.1.1f-1ubuntu2_amd64.deb -P /tmp

  sudo dpkg -i /tmp/libssl1.1_1.1.1f-1ubuntu2_amd64.deb
  sudo apt-get install -y xfonts-75dpi
  sudo dpkg -i /tmp/wkhtmltox_0.12.5-1.bionic_amd64.deb
  sudo apt install -f -y
)

echo "------------------------------------------------------------------------"
echo "🔧 Setting up Odoo configuration files"
echo "------------------------------------------------------------------------"
sleep 5s
sudo cp /opt/${ODOO_USER}/debian/odoo.conf /etc/odoo18.conf
sudo tee /etc/odoo18.conf > /dev/null <<EOF
[options]
admin_passwd = ${MASTER_PASSWORD}
db_host = localhost
db_port = 5432
db_user = ${ODOO_USER}
db_password = ${DB_PASSWORD}
addons_path = /opt/${ODOO_USER}/addons
default_productivity_apps = True
logfile = /var/log/odoo/odoo18.log
EOF
sudo chown ${ODOO_USER}: /etc/odoo18.conf
sudo chmod 640 /etc/odoo18.conf
sudo mkdir /var/log/odoo
sudo chown ${ODOO_USER}:root /var/log/odoo
sudo tee /etc/systemd/system/odoo18.service > /dev/null <<EOF
[Unit]
Description=Odoo18
Documentation=http://www.odoo.com

[Service]
# Ubuntu/Debian convention:
Type=simple
User=${ODOO_USER}
ExecStart=/opt/${ODOO_USER}/venv/bin/python /opt/${ODOO_USER}/odoo-bin -c /etc/odoo18.conf

[Install]
WantedBy=default.target
EOF
sudo chmod 755 /etc/systemd/system/odoo18.service
sudo chown root: /etc/systemd/system/odoo18.service
sudo chown -R ${ODOO_USER}: /opt/${ODOO_USER}

echo "------------------------------------------------------------------------"
echo "🎉 Odoo18 installation completed successfully!"
echo "What would you like to do next?"
echo "1  Start Odoo18 service only"
echo "2  Start and enable Odoo18 to run on system boot"
echo "------------------------------------------------------------------------"
echo -n "Enter your choice [1 or 2]: "

while true; do
  read -n 1 choice
  echo
  case $choice in
    1)
      echo "➡️  Starting Odoo18 service..."
      sudo systemctl daemon-reload
      sleep 5s
      sudo systemctl start odoo18.service
      break
      ;;
    2)
      echo "➡️  Starting and enabling Odoo18 service..."
      sudo systemctl daemon-reload
      sleep 5s
      sudo systemctl start odoo18.service
      sudo systemctl enable odoo18.service
      break
      ;;
    *)
      echo "❌ Invalid choice. Please enter 1 or 2:"
      ;;
  esac
done

SERVER_IP=$(hostname -I | awk '{print $1}')
sleep 5s
echo "------------------------------------------------------------------------"
echo 
echo "Helpful Odoo Commands & Information"
echo
echo "Odoo18 Service started successfully!, you can access it at http://${SERVER_IP}:8069"
echo "To monitor the Odoo logs, you can use the command: tail -f /var/log/odoo/odoo18.log"
echo "To enable Odoo to start on boot if not allready selected during installation, run: sudo systemctl enable odoo18.service"
echo "To stop Odoo, use: sudo systemctl stop odoo18.service"
echo "To restart Odoo, use: sudo systemctl restart odoo18.service"
echo "To get information about the Odoo service, use: sudo systemctl status odoo18.service"
echo "To view the Odoo configuration file, use: cat /etc/odoo18.conf"
echo "To view the Odoo service file, use: cat /etc/systemd/system/odoo18.service"
echo 
echo "------------------------------------------------------------------------"





