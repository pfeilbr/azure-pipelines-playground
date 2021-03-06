#!/usr/bin/env bash

set -o errexit
set -o nounset
set -o pipefail
set -o noglob

CONTENT_DIRECTORY_PATH="./public"

sync_s3() {
  content_directory_path=${1}
  bucket_name=${2}
  tag_name=${3}

  echo -e "Syncing assets..."
  aws s3 sync ${content_directory_path} s3://${bucket_name}/${tag_name} --delete
  echo -e "Done"
}



create_routing_rule() {
    bucket=$1
    prefix=$2
    target=$3
    redirect_location=$4

    aws s3api put-object \
        --bucket "${bucket}" \
        --key "${prefix}${target}" \
        --website-redirect-location "${redirect_location}" \
        --content-length "0"
}

create_routing_rules() {
    bucket=$1
    prefix=$2

    old_ifs=$IFS
    IFS=$'\r\n'
    GLOBIGNORE='*'
    rules=($(cat routing-rules/routing-rules.txt)) 
    echo "rules=${rules[@]}"

    for rule in "${rules[@]}"
    do
        echo "rule=${rule}"
        components=($(echo $rule | tr " " "\r\n"))
        echo "${components[@]}"
        target="${components[0]}"
        echo "target=${target}"
        redirect_location="${components[1]}"
        echo "target=${target}, redirect_location=${redirect_location}"

        create_routing_rule "${bucket}" "${prefix}" "${target}" "${redirect_location}"
    done

    IFS=${old_ifs}
}

change_origin_path() {
  tag_name=${1}
  cloudfront_distribution_id=${2}

  echo -e "Changing cloudfront origin..."
  current_distribution_config=$(aws cloudfront get-distribution --id ${cloudfront_distribution_id} --query "Distribution.DistributionConfig")
  current_origin_path=$(aws cloudfront get-distribution --id ${cloudfront_distribution_id} --query "Distribution.DistributionConfig.Origins.Items[1].OriginPath" --output text)
  
  echo current_distribution_config
  echo $current_distribution_config
  etag=$(aws cloudfront get-distribution --id ${cloudfront_distribution_id} --query "ETag" --output text)
  distribution_config_file_name="distribution_config.json"
  
  # update S3 bucket path
  new_origin_path="/${tag_name}"
  echo "${current_distribution_config//$current_origin_path/$new_origin_path}" > ${distribution_config_file_name}
  echo distribution_config_file_name
  cat ${distribution_config_file_name}
  aws cloudfront update-distribution --id ${cloudfront_distribution_id} --distribution-config file://${distribution_config_file_name} --if-match ${etag}
  echo -e "Done"
}

invalidate_cache() {
  cloudfront_distribution_id=${1}

  echo -e "Invalidating cloudfront cache..."
  aws cloudfront create-invalidation --distribution-id ${cloudfront_distribution_id} --paths "/*"
  echo -e "Done"
}

deploy_to_git_tag() {
  content_directory_path=${1}
  tag_name=${2}
  cloudfront_distribution_id=${3}
  bucket_name=${4}

  echo -e "Deploying ${tag_name}"
  sync_s3 ${content_directory_path} ${bucket_name} ${tag_name}
  create_routing_rules "${bucket_name}" "${tag_name}"
  change_origin_path ${tag_name} ${cloudfront_distribution_id}
  aws cloudfront wait distribution-deployed --id ${cloudfront_distribution_id}
  invalidate_cache ${cloudfront_distribution_id}
}

replace_in_file() {
  file_path=${1}
  search_value=${2}
  new_value=${3}
  sed -i "s/${search_value}/${new_value}/g" "${file_path}"
}

update_content_with_version() {
    file_path=${1}
    envsubst < "${file_path}" > "${file_path}.tmp"
    rm "${file_path}"
    mv "${file_path}.tmp" "${file_path}"
    # replace_in_file "${file_path}" "BUILD_SOURCEBRANCHNAME" "${BUILD_SOURCEBRANCHNAME}"
    # replace_in_file "${file_path}" "BUILD_SOURCEVERSION" "${BUILD_SOURCEVERSION}"
    # replace_in_file "${file_path}" "BUILD_SOURCEVERSIONMESSAGE" "${BUILD_SOURCEVERSIONMESSAGE}"
    cat ${file_path}
}

main() {
  branch="${BUILD_SOURCEBRANCHNAME}"
  content_directory_path=${CONTENT_DIRECTORY_PATH}
  index_file_path="${content_directory_path}/index.html"
  cloudfront_distribution_id=""
  bucket_name=""
  deploy_tag=""

  if [ "${branch}" = "develop" ]; then
    # TODO: chane the following to get staging distribution id and bucket name
    cloudfront_distribution_id=$(aws cloudformation describe-stacks --region "${REGION}" --stack-name "${STACK_NAME}" --query "Stacks[0].Outputs[?OutputKey=='StagingCloudFrontDistributionId'].OutputValue" --output text)
    bucket_name=$(aws cloudformation describe-stacks --region "${REGION}" --stack-name "${STACK_NAME}" --query "Stacks[0].Outputs[?OutputKey=='StagingWebsiteBucketName'].OutputValue" --output text)
    # tag name only.  no commit hash appended
    # deploy_tag=$(git describe --tags --abbrev=0)
    deploy_tag="${BUILD_SOURCEVERSION}" # commit sha-1 hash
  else
    cloudfront_distribution_id=$(aws cloudformation describe-stacks --region "${REGION}" --stack-name "${STACK_NAME}" --query "Stacks[0].Outputs[?OutputKey=='CloudFrontDistributionId'].OutputValue" --output text)
    bucket_name=$(aws cloudformation describe-stacks --region "${REGION}" --stack-name "${STACK_NAME}" --query "Stacks[0].Outputs[?OutputKey=='WebsiteBucketName'].OutputValue" --output text)
    # tag name only.  no commit hash appended
    # deploy_tag=$(git describe --tags --abbrev=0)
    deploy_tag="${BUILD_SOURCEVERSION}" # commit sha-1 hash
  fi

  echo "
  branch=${branch}
  content_directory_path=${content_directory_path}
  index_file_path=${index_file_path}
  cloudfront_distribution_id=${cloudfront_distribution_id}
  bucket_name=${bucket_name}
  deploy_tag=${deploy_tag}
  "

  #exit 0

  if [ "${deploy_tag}" ]; then
    update_content_with_version ${index_file_path}
    deploy_to_git_tag ${content_directory_path} ${deploy_tag} ${cloudfront_distribution_id} ${bucket_name}
    echo -e "Deploy success"
  else
    echo -e "Deploy failure: no tag"
  fi
}

start_time="$(date -u +%s)"
main "$@"
end_time="$(date -u +%s)"
elapsed="$(($end_time-$start_time))"
echo "Total of $elapsed seconds elapsed for process"


