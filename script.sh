#!/bin/bash
component=$1
environment=$2
app_version=$3
sudo dnf install ansible -y
sudo mkdir -p /var/log/roboshop1
sudo chown ec2-user:ec2-user /var/log/roboshop1
sudo chmod -R 755  /var/log/roboshop1
touch /var/log/roboshop1/ansible.log

cd /home/ec2-user
git clone https://github.com/srikanth-865/roboshop-ansible-v3.git
cd roboshop-ansible-v3
git pull
ansible-playbook -e component=$component -e env=$environment  -e app_version=$app_version roboshop.yaml

