#!/usr/bin/env bash

#set -o errexit
set -o nounset
set -o pipefail
set -o noglob

REGION="us-east-1"
PROVISIONING_STACK_NAME="dev-bootstrap-agency-website"
STACK_NAME="dev-agency-website"
DOMAIN_NAME="allthecloudbits.com"
AUTOMATION_USER_PASSWORD="automation123"
read -r -d '' TAGS <<- EOM
    Name=tagName \
    Costcenter=tagCostcenter \
    Division=tagDivision \
    Environment=tagEnvironment \
    Application=tagApplication \
    Consumer=tagConsumer
EOM

CMD=$1

bootstrap() {
    aws cloudformation deploy \
        --region "${REGION}" \
        --template cfn-templates/provisioning-resources.yaml \
        --stack-name ${PROVISIONING_STACK_NAME} \
        --parameter-overrides ResourcePrefix=${STACK_NAME} \
        --capabilities CAPABILITY_IAM \
        --tags ${TAGS}

    [ -d tmp ] || mkdir tmp
    stack_outputs_file_path="tmp/${PROVISIONING_STACK_NAME}-outputs.json"

    aws cloudformation describe-stacks \
        --region "${REGION}" \
        --stack-name "${PROVISIONING_STACK_NAME}" \
        --query "Stacks[0].Outputs" \
        --output json > "${stack_outputs_file_path}"    
}

create() {
    aws cloudformation deploy \
        --region "${REGION}" \
        --template cfn-templates/resources.yaml \
        --stack-name ${STACK_NAME} \
        --parameter-overrides DomainName=${DOMAIN_NAME} AutomationUserPassword=${AUTOMATION_USER_PASSWORD} \
        --capabilities CAPABILITY_IAM \
        --tags \
            Name=tagName \
            Costcenter=tagCostcenter \
            Division=tagDivision \
            Environment=tagEnvironment \
            Application=tagApplication \
            Consumer=tagConsumer

    [ -d tmp ] || mkdir tmp
    stack_outputs_file_path="tmp/${STACK_NAME}-outputs.json"

    aws cloudformation describe-stacks \
        --region "${REGION}" \
        --stack-name "${STACK_NAME}" \
        --query "Stacks[0].Outputs" \
        --output json > "${stack_outputs_file_path}"

    echo stack outputs written to "${stack_outputs_file_path}"
}

delete() {

    website_bucket_name=$(aws cloudformation describe-stacks --region "${REGION}" --stack-name "${STACK_NAME}" --query "Stacks[0].Outputs[?OutputKey=='WebsiteBucketName'].OutputValue" --output text)
    cloudfront_logs_bucket_name=$(aws cloudformation describe-stacks --region "${REGION}" --stack-name "${STACK_NAME}" --query "Stacks[0].Outputs[?OutputKey=='CloudFrontLogsBucketName'].OutputValue" --output text)
    
    aws s3 rb "s3://${website_bucket_name}" --force
    aws s3 rb "s3://${cloudfront_logs_bucket_name}" --force

    aws cloudformation delete-stack \
        --region "${REGION}" \
        --stack-name "${STACK_NAME}"

    aws cloudformation wait stack-delete-complete \
        --region "${REGION}" \
        --stack-name "${STACK_NAME}"

}

case $CMD in
    bootstrap)
        bootstrap
    ;;
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
