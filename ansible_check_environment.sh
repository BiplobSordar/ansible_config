#!/usr/bin/env bash

sudo apt update
sudo apt install -y ansible

ansible --version

cd ~/ansible_config
ansible-galaxy collection install -r requirements.yml
ansible-galaxy collection list

python3 scripts/generate_tf_vars.py



ansible-inventory -i inventory/aws_ec2.yml --graph


ansible-inventory -i inventory/aws_ec2.yml --list

ansible-playbook -i inventory/aws_ec2.yml playbooks/site.yml -vv