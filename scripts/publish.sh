#!/usr/bin/env bash

set -o errexit
set -o nounset
set -o pipefail
set -o noglob

CLOUDFRONT_DISTRIBUTION_ID="E3490EXSMQAI3D"
BUCKET_NAME="com.merck.mysite01"
CONTENT_DIRECTORY_PATH="./public"

sync_s3() {
  content_directory_path=${1}
  bucket_name=${2}
  tag_name=${3}

  echo -e "Syncing assets..."
  aws s3 sync ${content_directory_path} s3://${bucket_name}/${tag_name} --delete
  echo -e "Done"
}

change_origin_path() {
  tag_name=${1}
  cloudfront_distribution_id=${2}

  previous_tag_name=$(git describe --abbrev=0 --tags `git rev-list --tags --skip=1  --max-count=1`)

  echo -e "Changing cloudfront origin..."
  current_distribution_config=$(aws cloudfront get-distribution --id ${cloudfront_distribution_id} --query "Distribution.DistributionConfig")
  echo current_distribution_config
  echo $current_distribution_config
  etag=$(aws cloudfront get-distribution --id ${cloudfront_distribution_id} --query "ETag" --output text)
  distribution_config_file_name="distribution_config.json"
  
  # update S3 bucket path
  echo $current_distribution_config | sed "s/${previous_tag_name}/${tag_name}/g" > ${distribution_config_file_name}
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
  change_origin_path ${tag_name} ${cloudfront_distribution_id}
  aws cloudfront wait distribution-deployed --id ${cloudfront_distribution_id}
  invalidate_cache ${cloudfront_distribution_id}
}

update_content_with_version() {
    file_path=${1}
    version_placeholder="__VERSION__"
    sed -i "s/${version_placeholder}/${deploy_tag}/g" "${file_path}"
    cat ${file_path}
}

main() {
  content_directory_path=${CONTENT_DIRECTORY_PATH}
  index_file_path="${content_directory_path}/index.html"
  cloudfront_distribution_id=${CLOUDFRONT_DISTRIBUTION_ID}
  bucket_name=${BUCKET_NAME}
  # tag name only.  no commit hash appended
  deploy_tag=$(git describe --tags --abbrev=0)


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


