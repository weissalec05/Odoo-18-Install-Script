#!/bin/bash

#Variablen für die Installation
ODOO_USER="odoo18" #Odoo-Benutzer ist auch der Datenbankbenutzer
DB_PASSWORD=""
MASTER_PASSWORD="" #Dies ist das Passwort, das Datenbankoperationen erlaubt

if [[ -z "$ODOO_USER" || -z "$DB_PASSWORD" || -z "$MASTER_PASSWORD" ]]; then
    echo "------------------------------------------------------------------------"
    echo "❌ Eine oder mehrere erforderliche Variablen (ODOO_USER, DB_PASSWORD, MASTER_PASSWORD) sind nicht gesetzt."
    echo "💡 Bitte setzen Sie alle Variablen, bevor Sie das Skript ausführen."
    echo "------------------------------------------------------------------------"
    exit 1
fi

echo "------------------------------------------------------------------------"
echo "🔄 Server wird aktualisiert und benötigte Pakete werden installiert..."
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
echo "🛡️ Fail2ban wird gestartet und aktiviert"
echo "------------------------------------------------------------------------"
sleep 5s
sudo systemctl start fail2ban
sudo systemctl enable fail2ban

echo "------------------------------------------------------------------------"
echo "🗂️ PostgreSQL-Datenbank und Benutzer werden eingerichtet"
echo "------------------------------------------------------------------------"
sleep 5s
sudo apt-get install -y postgresql
sleep 1s
sudo -u postgres psql -c "CREATE ROLE odoo18 WITH CREATEDB SUPERUSER LOGIN PASSWORD '${DB_PASSWORD}';"

echo "------------------------------------------------------------------------"
echo "🙍 Odoo-Systembenutzer wird erstellt"
echo "------------------------------------------------------------------------"
sleep 5s
sudo adduser --system --home=/opt/${ODOO_USER} --group ${ODOO_USER}

echo "------------------------------------------------------------------------"
echo "📥 Odoo18 wird von Github heruntergeladen und installiert"
echo "------------------------------------------------------------------------"
sleep 5s
sudo rm -rf /opt/${ODOO_USER}
git clone https://github.com/odoo/odoo --depth 1 --branch 18.0 --single-branch /opt/${ODOO_USER}

echo "------------------------------------------------------------------------"
echo "🛠️ Python-virtuelle Umgebung wird erstellt und Abhängigkeiten werden installiert"
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
echo "🔧 Odoo-Konfigurationsdateien werden eingerichtet"
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
# Ubuntu/Debian-Konvention:
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
echo "🎉 Odoo18-Installation wurde erfolgreich abgeschlossen!"
echo "Was möchten Sie als Nächstes tun?"
echo "1  Nur Odoo18-Dienst starten"
echo "2  Odoo18 starten und beim Systemstart aktivieren"
echo "------------------------------------------------------------------------"
echo -n "Geben Sie Ihre Auswahl ein [1 oder 2]: "

while true; do
  read -n 1 choice
  echo
  case $choice in
    1)
      echo "➡️  Odoo18-Dienst wird gestartet..."
      sudo systemctl daemon-reload
      sleep 5s
      sudo systemctl start odoo18.service
      break
      ;;
    2)
      echo "➡️  Odoo18-Dienst wird gestartet und beim Booten aktiviert..."
      sudo systemctl daemon-reload
      sleep 5s
      sudo systemctl start odoo18.service
      sudo systemctl enable odoo18.service
      break
      ;;
    *)
      echo "❌ Ungültige Auswahl. Bitte geben Sie 1 oder 2 ein:"
      ;;
  esac
done

SERVER_IP=$(hostname -I | awk '{print $1}')
sleep 5s
echo "------------------------------------------------------------------------"
echo 
echo "Hilfreiche Odoo-Befehle & Informationen"
echo
echo "Odoo18-Dienst wurde erfolgreich gestartet! Sie können darauf zugreifen unter http://${SERVER_IP}:8069"
echo "Um die Odoo-Protokolle zu überwachen, verwenden Sie den Befehl: tail -f /var/log/odoo/odoo18.log"
echo "Um Odoo beim Booten zu aktivieren, falls nicht während der Installation ausgewählt, führen Sie aus: sudo systemctl enable odoo18.service"
echo "Um Odoo zu stoppen, verwenden Sie: sudo systemctl stop odoo18.service"
echo "Um Odoo neu zu starten, verwenden Sie: sudo systemctl restart odoo18.service"
echo "Um Informationen über den Odoo-Dienst zu erhalten, verwenden Sie: sudo systemctl status odoo18.service"
echo "Um die Odoo-Konfigurationsdatei anzuzeigen, verwenden Sie: cat /etc/odoo18.conf"
echo "Um die Odoo-Dienstdatei anzuzeigen, verwenden Sie: cat /etc/systemd/system/odoo18.service"
echo 
echo "------------------------------------------------------------------------"
