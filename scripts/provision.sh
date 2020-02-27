#!/usr/bin/env bash

#set -o errexit
set -o nounset
set -o pipefail
set -o noglob

STACK_NAME="automation"
aws cloudformation deploy \
    --template cfn-templates/${STACK_NAME}-stack.yaml \
    --stack-name ${STACK_NAME}-stack \
    --parameter-overrides Password=automation123 \
    --capabilities CAPABILITY_IAM

aws cloudformation describe-stacks \
    --stack-name "${STACK_NAME}-stack" \
    --query "Stacks[0].Outputs" \
    --output json