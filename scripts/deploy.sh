#!/usr/bin/env bash

aws s3 ls | head -n 1
pwd
ls -alt

set -o errexit
set -o nounset
set -o pipefail
set -o noglob

CLOUDFRONT_DISTRIBUTION_ID="E2IL5HY5XTHLNW"
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

  echo -e "Changing cloudfront origin..."
  current_distribution_config=$(aws cloudfront get-distribution --id ${cloudfront_distribution_id})
  echo $current_distribution_config
#   next_distribution_config=$(bin/lib/update-distribution ${tag_name} "${current_distribution_config}")
#   etag=$(bin/lib/get-etag "${current_distribution_config}")
  next_distribution_config="my_next_distribution_config"
  etag="my_etag"
  echo aws cloudfront update-distribution --id ${cloudfront_distribution_id} --distribution-config ${next_distribution_config} --if-match ${etag}
  echo -e "Done"
}

invalidate_cache() {
  cloudfront_distribution_id=${1}

  echo -e "Invalidating cloudfront cache..."
  echo aws cloudfront create-invalidation --distribution-id ${cloudfront_distribution_id} --paths /*
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
  echo aws cloudfront wait distribution-deployed --id ${cloudfront_distribution_id}
  invalidate_cache ${cloudfront_distribution_id}
}

main() {
  content_directory_path=${CONTENT_DIRECTORY_PATH}
  cloudfront_distribution_id=${CLOUDFRONT_DISTRIBUTION_ID}
  bucket_name=${BUCKET_NAME}
  deploy_tag=$(git describe --tags --abbrev=0)


  if [ "${deploy_tag}" ]; then
    index_file_path="./public/index.html"
    version_placeholder="__VERSION__"
    sed -i "s/${version_placeholder}/${deploy_tag}/g" "${index_file_path}"
    cat ${index_file_path}

    deploy_to_git_tag ${content_directory_path} ${deploy_tag} ${cloudfront_distribution_id} ${bucket_name}
    echo -e "Deploy success"
  else
    echo -e "Deploy failure: no tag"
  fi
}

main "$@"
