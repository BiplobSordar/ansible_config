#!/usr/bin/env bash

set -e

GREEN="\033[0;32m"
RED="\033[0;31m"
YELLOW="\033[1;33m"
NC="\033[0m"


echo "================================================="
echo " Ansible Kubernetes Environment Validation"
echo "================================================="


check_command()
{
    CMD=$1

    if command -v $CMD >/dev/null 2>&1
    then
        echo -e "${GREEN}[OK]${NC} $CMD installed"
        $CMD --version | head -n 1 || true
    else
        echo -e "${RED}[FAILED]${NC} $CMD missing"
    fi
}


check_collection()
{
    COLLECTION=$1

    if ansible-galaxy collection list | grep -q $COLLECTION
    then
        VERSION=$(ansible-galaxy collection list | grep $COLLECTION | awk '{print $2}')
        echo -e "${GREEN}[OK]${NC} $COLLECTION ($VERSION)"
    else
        echo -e "${RED}[FAILED]${NC} $COLLECTION missing"
    fi
}



echo ""
echo "############ Basic Tools ############"

check_command ansible
check_command ansible-playbook
check_command terraform
check_command aws
check_command python3
check_command kubectl


echo ""
echo "############ Ansible Version ############"

ansible --version


echo ""
echo "############ Python Packages ############"


PYTHON_PACKAGES="
boto3
botocore
jmespath
"


for pkg in $PYTHON_PACKAGES
do

    if python3 -c "import $pkg" >/dev/null 2>&1
    then
        echo -e "${GREEN}[OK]${NC} python package $pkg"
    else
        echo -e "${RED}[FAILED]${NC} python package $pkg missing"
    fi

done



echo ""
echo "############ Ansible Collections ############"


COLLECTIONS="
amazon.aws
community.aws
kubernetes.core
ansible.posix
community.general
"


for col in $COLLECTIONS
do
    check_collection $col
done



echo ""
echo "############ AWS Check ############"


if aws sts get-caller-identity >/dev/null 2>&1
then

    echo -e "${GREEN}[OK]${NC} AWS credentials working"

    aws sts get-caller-identity

else

    echo -e "${RED}[FAILED]${NC} AWS credentials not configured"

fi



echo ""
echo "############ Terraform Output Check ############"


TERRAFORM_JSON="terraform/outputs.json"


if [ -f "$TERRAFORM_JSON" ]
then

    echo -e "${GREEN}[OK]${NC} Terraform output exists"

    jq '. | keys' $TERRAFORM_JSON


else

    echo -e "${YELLOW}[WARNING]${NC} terraform/outputs.json missing"

fi



echo ""
echo "############ Ansible Inventory Check ############"


if [ -f "inventory/aws_ec2.yml" ]
then

    echo -e "${GREEN}[OK]${NC} Dynamic inventory file exists"


    ansible-inventory \
    -i inventory/aws_ec2.yml \
    --graph


else

    echo -e "${RED}[FAILED]${NC} inventory/aws_ec2.yml missing"

fi



echo ""
echo "############ AWS SSM Module Check ############"


if ansible-doc amazon.aws.ssm_parameter >/dev/null 2>&1
then

    echo -e "${GREEN}[OK]${NC} amazon.aws.ssm_parameter available"

else

    echo -e "${RED}[FAILED]${NC} amazon.aws.ssm_parameter missing"

fi



echo ""
echo "############ Kubernetes Modules Check ############"


if ansible-doc kubernetes.core.k8s >/dev/null 2>&1
then

    echo -e "${GREEN}[OK]${NC} kubernetes.core.k8s available"

else

    echo -e "${YELLOW}[WARNING]${NC} kubernetes.core.k8s missing"

fi



echo ""
echo "############ Container Runtime Check ############"


if command -v crictl >/dev/null 2>&1
then

    echo -e "${GREEN}[OK]${NC} crictl installed"

    crictl info | grep runtimeName || true

else

    echo -e "${YELLOW}[WARNING]${NC} crictl missing"

fi



echo ""
echo "############ Final Summary ############"

echo ""
echo "Environment validation completed."
echo ""

echo "Next commands:"
echo ""
echo "ansible-inventory -i inventory/aws_ec2.yml --graph"
echo ""
echo "ansible-playbook -i inventory/aws_ec2.yml playbooks/site.yml"
echo ""
