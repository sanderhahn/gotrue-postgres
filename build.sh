set -e

sudo apt-get update -y

git clone https://github.com/netlify/gotrue.git || true
cd gotrue

sudo snap install go --classic
go build
go install

function append_profile {
    grep -qxF "$1" /home/ubuntu/.profile || echo "$1" >>/home/ubuntu/.profile
}

append_profile 'export PATH=$PATH:$HOME/go/bin >>/home/ubuntu/.profile'
append_profile 'export DATABASE_URL="postgres://gotrue:weceekae5iequiquiy9E@localhost/gotrue"'
append_profile 'export GOTRUE_DB_DRIVER=postgres'
append_profile 'export GOTRUE_OPERATOR_TOKEN=Aixoyooh9yaethoos3keiquoht9elohG'
append_profile 'export GOTRUE_SITE_URL=http://yoursite/'
append_profile 'export GOTRUE_JWT_SECRET=behohShez0aegh6naequo3muoM4reeB1ushiengeeNiimohpoChai8ie2Quei5ah'
append_profile 'export GOTRUE_JWT_AUD=netlify'

source ~/.profile

sudo apt-get -y install mysql-server

sudo mysql -u root -e "create database gotrue;" || true
sudo mysql -u root -e "create user 'gotrue'@'localhost' identified with mysql_native_password by 'weceekae5iequiquiy9E';" || true
sudo mysql -u root -e "grant all on gotrue.* TO 'gotrue'@'localhost';" || true
sudo mysql -u root -e "flush privileges;"

export DATABASE_URL="gotrue:weceekae5iequiquiy9E@/gotrue?parseTime=true&multiStatements=true"
export GOTRUE_DB_DRIVER=mysql
gotrue migrate

sudo apt-get -y install postgresql
sudo -u postgres psql postgres postgres -c "create user gotrue with encrypted password 'weceekae5iequiquiy9E';" || true
sudo -u postgres psql postgres postgres -c "create database gotrue owner = gotrue;" || true

sudo apt-get install -y pgloader
sudo pgloader mysql://gotrue:weceekae5iequiquiy9E@localhost/gotrue postgres://gotrue:weceekae5iequiquiy9E@localhost/gotrue

export DATABASE_URL="postgres://gotrue:weceekae5iequiquiy9E@localhost/gotrue"
export GOTRUE_DB_DRIVER=postgres
gotrue migrate

cat <<-SQL | psql -v ON_ERROR_STOP=ON $DATABASE_URL
alter table gotrue.audit_log_entries alter column instance_id type uuid using instance_id::uuid;
alter table gotrue.audit_log_entries alter column id type uuid using id::uuid;

alter table gotrue.instances alter column id type uuid using id::uuid;
alter table gotrue.instances alter column uuid type uuid using uuid::uuid;

alter table gotrue.refresh_tokens alter column instance_id type uuid using instance_id::uuid;
alter table gotrue.refresh_tokens alter column user_id type uuid using user_id::uuid;

alter table gotrue.users alter column instance_id type uuid using instance_id::uuid;
alter table gotrue.users alter column id type uuid using id::uuid;
SQL

cat <<-EOF | sudo tee /etc/systemd/system/gotrue.service
[Unit]
Description=gotrue
After=syslog.target network.target postgresql.service

[Service]
Environment=DATABASE_URL="postgres://gotrue:weceekae5iequiquiy9E@localhost/gotrue"
Environment=GOTRUE_DB_DRIVER=postgres
Environment=GOTRUE_OPERATOR_TOKEN=Aixoyooh9yaethoos3keiquoht9elohG
Environment=GOTRUE_SITE_URL=http://yoursite/
Environment=GOTRUE_JWT_SECRET=behohShez0aegh6naequo3muoM4reeB1ushiengeeNiimohpoChai8ie2Quei5ah
Environment=GOTRUE_JWT_EXP=3600
Environment=GOTRUE_JWT_AUD=netlify
Environment=MAILER_AUTOCONFIRM=true
#Environment=GOTRUE_SMTP_HOST=
#Environment=GOTRUE_SMTP_PORT=587
#Environment=GOTRUE_SMTP_USER=
#Environment=GOTRUE_SMTP_PASS=
#Environment=GOTRUE_SMTP_ADMIN_EMAIL=

User=ubuntu
ExecStart=/home/ubuntu/go/bin/gotrue

[Install]
WantedBy=multi-user.target
EOF
sudo chmod +x /etc/systemd/system/gotrue.service

sudo systemctl daemon-reload
sudo systemctl start gotrue
sudo systemctl enable gotrue

sudo apt-get install -y httpie jq
