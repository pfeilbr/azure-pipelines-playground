#!/usr/bin/env bash

#set -o errexit
set -o nounset
set -o pipefail
set -o noglob

STACK_NAME="automation"
DOMAIN_NAME="allthecloudbits.com"
AUTOMATION_USER_PASSWORD="automation123"

aws cloudformation deploy \
    --template cfn-templates/${STACK_NAME}-stack.yaml \
    --stack-name ${STACK_NAME}-stack \
    --parameter-overrides DomainName=${DOMAIN_NAME} AutomationUserPassword=${AUTOMATION_USER_PASSWORD} \
    --capabilities CAPABILITY_IAM

[ -d tmp ] || mkdir tmp
stack_outputs_file_path="tmp/${STACK_NAME}-stack-outputs.json"

aws cloudformation describe-stacks \
    --stack-name "${STACK_NAME}-stack" \
    --query "Stacks[0].Outputs" \
    --output json > "${stack_outputs_file_path}"

echo stack outputs written to "${stack_outputs_file_path}"