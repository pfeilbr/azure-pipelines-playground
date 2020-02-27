#!/usr/bin/env bash

#set -o errexit
set -o nounset
set -o pipefail
set -o noglob

STACK_NAME="dev-agency-website"
DOMAIN_NAME="allthecloudbits.com"
AUTOMATION_USER_PASSWORD="automation123"

CMD=$1

create() {
    aws cloudformation deploy \
        --template cfn-templates/resources.yaml \
        --stack-name ${STACK_NAME} \
        --parameter-overrides DomainName=${DOMAIN_NAME} AutomationUserPassword=${AUTOMATION_USER_PASSWORD} \
        --capabilities CAPABILITY_IAM

    [ -d tmp ] || mkdir tmp
    stack_outputs_file_path="tmp/${STACK_NAME}-outputs.json"

    aws cloudformation describe-stacks \
        --stack-name "${STACK_NAME}" \
        --query "Stacks[0].Outputs" \
        --output json > "${stack_outputs_file_path}"

    echo stack outputs written to "${stack_outputs_file_path}"
}

delete() {
    aws cloudformation delete-stack \
        --stack-name "${STACK_NAME}"

}

case $CMD in
    create)
        create
    ;;
    delete)
        read -r -p "Are you sure want to delete the stack? [y/N] " response
        if [[ "$response" =~ ^([yY][eE][sS]|[yY])$ ]]
        then
            delete
        fi           
    ;;
esac
