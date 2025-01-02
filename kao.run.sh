#!/bin/bash
sudo apt update
sudo apt upgrade -y
sudo apt install -y ufw crowdsec fail2ban

DEFAULT_IPS=("127.0.0.1" "::1")
if [ -n "${PRIVATE_IPS}" ]; then
    ALLOWED_IPS=("${DEFAULT_IPS[@]}" "${PRIVATE_IPS[@]}")
else
    ALLOWED_IPS=("${DEFAULT_IPS[@]}")
fi

sudo ufw default deny incoming
sudo ufw default allow outgoing
for ip in "${ALLOWED_IPS[@]}"; do
    sudo ufw allow from $ip to any port 22
done
sudo ufw enable

for ip in "${ALLOWED_IPS[@]}"; do
    sudo cscli decisions add --ip $ip --type whitelist
done

cp /etc/fail2ban/jail.conf /etc/fail2ban/jail.local
sudo sed -i "s|^ignoreip = 127.0.0.1.*|ignoreip = ${ALLOWED_IPS[@]}|" /etc/fail2ban/jail.local

sudo bash -c 'cat <<EOF >> /etc/fail2ban/jail.local

[sshd]
enabled = true
port = ssh
filter = sshd
logpath = journal
backend = systemd
maxretry = 2
findtime = 300
banaction = iptables-allports
bantime = 86400
EOF'

# Restart services to apply changes
sudo systemctl restart ufw
sudo systemctl restart crowdsec
sudo systemctl restart fail2ban