#!/usr/bin/env bash

aws s3 ls | head -n 1
pwd
ls -alt

set -o errexit
set -o nounset
set -o pipefail
set -o noglob

CLOUDFRONT_DISTRIBUTION_ID='distribution123'
BUCKET_NAME='mysite01'

sync_s3() {
  bucket_name=${1}
  tag_name=${2}

  echo -e "Syncing assets..."
  echo aws s3 sync ./public s3://${bucket_name}/${tag_name} --delete
  echo -e "Done"
}

change_origin_path() {
  tag_name=${1}
  cloudfront_distribution_id=${2}

  echo -e "Changing cloudfront origin..."
#   current_distribution_config=$(aws cloudfront get-distribution --id ${cloudfront_distribution_id})
#   next_distribution_config=$(bin/lib/update-distribution ${tag_name} "${current_distribution_config}")
#   etag=$(bin/lib/get-etag "${current_distribution_config}")
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
  tag_name=${1}
  cloudfront_distribution_id=${2}
  bucket_name=${3}

  echo -e "Deploying ${tag_name}"
  sync_s3 ${bucket_name} ${tag_name}
  change_origin_path ${tag_name} ${cloudfront_distribution_id}
  echo aws cloudfront wait distribution-deployed --id ${cloudfront_distribution_id}
  invalidate_cache ${cloudfront_distribution_id}
}

main() {
  cloudfront_distribution_id=${CLOUDFRONT_DISTRIBUTION_ID}
  bucket_name=${BUCKET_NAME}
  deploy_tag=$(git describe)

  if [ "${deploy_tag}" ]; then
    deploy_to_git_tag ${deploy_tag} ${cloudfront_distribution_id} ${bucket_name}
    echo -e "Deploy success"
  else
    echo -e "Deploy failure: no tag"
  fi
}

main "$@"
