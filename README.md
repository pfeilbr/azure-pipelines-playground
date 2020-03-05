# azure-pipelines-playground

learn [azure pipelines](https://docs.microsoft.com/en-us/azure/devops/pipelines/?view=azure-devops)

## Description

Pipeline performs an atomic deploy of static content from a github repo to a static site (CloudFront + S3 when) a tag (release)
is applied to the repo

## Infrastructure Provisioning Steps

1. create route 53 hosted zone for your domain name (e.g. `mydomain.com`)
1. update `DOMAIN_NAME` parameter in [`scripts/stack.sh`](scripts/stack.sh) with the hosted zone name 
1. provision aws resources `./scripts/stack.sh create`
1. Check ACM to confirm Certificate validation via DNS validation has completed.  May need to add DNS validation records to route53 hosted zone.
1. update pipeline variables
    * REGION - *default is us-east-1*
    * STACK_NAME - defined in [`scripts/stack.sh`](scripts/stack.sh)
    * AWS_ACCESS_KEY_ID - `AccessKey` output in `./tmp/${STACK_NAME}-outputs.json`
    * AWS_SECRET_ACCESS_KEY - `SecretKey` output in `./tmp/${STACK_NAME}-outputs.json`

## Website Content Publishing Steps

1. update website content in [`public`](public) directory and push to github.
1. update `TAG_NAME` in `./scripts/tag-and-trigger-publish.sh` with your version.
1. trigger a pipeline run via a tag `./scripts/tag-and-trigger-publish.sh "v0.0.1"`.  
1. publish will run.  can take up to 20 minutes to complete due CloudFront distribution update.
1. verify updated content by visiting <https://mydomain.com> and <https://www.mydomain.com>

## Deprovisioning

1. deprovision aws resources `./scripts/stack.sh delete`
1. *(optional)* manually delete S3 website and CloudFront logs buckets.
    > these are not deleted because they still contain objects
1. *(optional)* run `./scripts/stack.sh delete` again to permanently delete stack

---

## Key Files and Directories

* [`cfn-templates/resources.yaml`](cfn-templates/resources.yaml) - CloudFormation stack for provisioning AWS resources.
    * S3 bucket for static content
    * CloudFront distribution
    * SSL Certificate (ACM)
    * route53 root domain ALIAS record to CloudFront distribution
    * route53 www CNAME record to CloudFront distribution
    * IAM user for CI/CD automation used by the azure pipeline
* [`public`](public) - static web content
* [`scripts/stack.sh`](scripts/stack.sh) - provisions AWS resources
* [`tmp/automation-outputs.json`](tmp/automation-stack-outputs.json) - stack outputs stored here.  *file gets created when stack is provisioned.*
* [`scripts/tag-and-trigger-publish.sh`](scripts/tag-and-trigger-publish.sh) - tags and pushes the tag to github to trigger the publish pipeline
* [`scripts/publish.sh`](scripts/publish.sh) - publishes a new version of the static site based on git tag.  this is used by pipeline
* [`azure-pipelines.yml`](azure-pipelines.yml) - pipeline definition that get triggered on tag to publish to site


---

## Screenshots

**Pipeline Variables**

![](https://www.evernote.com/l/AAHE5oOGeN9Kv7oZa-EDbz0NwbJwlITnmBkB/image.png)

---

## TODO

* add staging CloudFront distribution
    * options
        * separate bucket s3://stage s3://prod
        * single bucket with prefix s3://bucket/stage/* s3://bucket/prod/*
* create IAM policy and role for resource provisioning
    * look at CloudFormation | Stack | Resources view for resource types
    * specify resource name prefix and suffix as variable to allow for change
    * specify role-arn for cloudformation cli 

## Completed / Cancelled

* update s3 redirect/routing rules for deploy version prefix
    * e.g. domain.com/oldlink would point to /v0.0.1/newlink in the bucket. the `/v0.0.1` prefix need to be updated in all redirect rules on deploy
    * see https://docs.aws.amazon.com/cli/latest/reference/s3api/put-bucket-website.html
* redirects
    * options
        * via lambda@edge
        *  check if WAF supports
        * S3 bucket routing rules (`AWS::S3::Bucket RoutingRule`)
        * s3 object metadata header. see [(Optional) Configuring a Webpage Redirect](https://docs.aws.amazon.com/AmazonS3/latest/dev/how-to-page-redirect.html#advanced-conditional-redirects) and [`x-amz-website-redirect-location`](https://docs.aws.amazon.com/AmazonS3/latest/API/API_CopyObject.html#RESTObjectCOPY-requests-request-headers) 
            > If the bucket is configured as a website, redirects requests for this object to another object in the same bucket or to an external URL. Amazon S3 stores the value of this header in the object metadata.
            * trailing slashes: see the following on how to handle [Re: S3 make a non-trailing slash URL send a 301 instead of a 302](https://forums.aws.amazon.com/thread.jspa?threadID=168000#jive-message-592535)
* basic auth on staging cloudfront dist
    * options
        * lambda@edge
        * WAF rule for Authorization header
* update `scripts/publish.sh` with proper cache control for index.html (no-cache)
    ```sh
    aws s3 sync --cache-control 'max-age=604800' --exclude index.html build/ s3://mywebsitebucket/
    aws s3 sync --cache-control 'no-cache' build/ s3://mywebsitebucket/
    ```
* deny requests directly to s3.  must use domain.  remove OAI and add this.  this will allows redirects in S3 to work.
    * see [How do I use CloudFront to serve a static website hosted on Amazon S3?](https://aws.amazon.com/premiumsupport/knowledge-center/cloudfront-serve-static-website/) for details.
    * TLDR; the referer is set on the CloudFront distribution and is a secret.  the S3 bucket policy only allows requests from this referer
    * [I’m using an S3 REST API endpoint as the origin of my CloudFront distribution. Why am I getting 403 Access Denied errors?](https://aws.amazon.com/premiumsupport/knowledge-center/s3-rest-api-cloudfront-error-403/)
    * [I’m using an S3 website endpoint as the origin of my CloudFront distribution. Why am I getting 403 Access Denied errors?](https://aws.amazon.com/premiumsupport/knowledge-center/s3-website-cloudfront-error-403/)
        ```json
        {
            "Version": "2012-10-17",
            "Id": "http referer policy ${DomainName}",
            "Statement": [
                {
                    "Sid": "Allow get requests referred by ${DomainName}",
                    "Effect": "Allow",
                    "Principal": "*",
                    "Action": "s3:GetObject",
                    "Resource": "arn:aws:s3:::${BUCKET}/*",
                    "Condition": {
                        "StringLike": {
                            "aws:Referer": [
                                "http://${DomainName}/*",
                                "https://${DomainName}/*"
                            ]
                        }
                    }
                },
                {
                    "Sid": "Explicit deny to ensure requests are allowed only from specific referer.",
                    "Effect": "Deny",
                    "Principal": "*",
                    "Action": "s3:GetObject",
                    "Resource": "arn:aws:s3:::${BUCKET}/*",
                    "Condition": {
                        "StringNotLike": {
                            "aws:Referer": [
                                "http://${DomainName}/*",
                                "https://${DomainName}/*"
                            ]
                        }
                    }
                }
            ]
        }
        ```


---

## Notes

* pipeline is running in azure DevOps tied to personal gmail account

---

## Scratch

```sh
# delete all remote tags
git tag -l | xargs -n 1 git push --delete origin

# delete all local tags
git tag | xargs git tag -d

#REDIRECT_LOCATION="https://allthecloudbits.com/products/product02/"

REGION="us-east-1"
STACK_NAME="dev-agency-website"
BUCKET=$(aws cloudformation describe-stacks --region "${REGION}" --stack-name "${STACK_NAME}" --query "Stacks[0].Outputs[?OutputKey=='WebsiteBucketName'].OutputValue" --output text)
PREFIX="v0.0.1"

TARGET="${PREFIX}/about"
REDIRECT_LOCATION="/about/"

aws --profile automation-user s3api put-object \
    --bucket "${BUCKET}" \
    --key "${TARGET}" \
    --website-redirect-location "${REDIRECT_LOCATION}" \
    --content-length "0"

aws --profile automation-user s3api head-object \
    --bucket "${BUCKET}" \
    --key "${TARGET}"

aws --profile automation-user s3api delete-object \
    --bucket "${BUCKET}" \
    --key "${TARGET}"


aws --profile automation-user s3api list-objects \
    --bucket "${BUCKET}"
```

policy components
```json
{
    "Effect": "Allow",
    "Principal": "arn:aws:iam::529276214230:user/admin",
    "Action": "s3:*",
    "Resource": "arn:aws:s3:::dev-agency-website-s3bucketforwebsitecontent-11u56g1n9u9oo/*",
},
{
    "Effect": "Allow",
    "Principal": "*",
    "Action": "s3:GetObject",
    "Resource": "arn:aws:s3:::dev-agency-website-s3bucketforwebsitecontent-11u56g1n9u9oo/*",
    "Condition": {
        "StringLike": {
            "aws:Referer": "79011a81-c048-4877-84f4-efe9577d7250"
        }
    }
},
{
    "Effect": "Deny",
    "Principal": "*",
    "Action": "s3:GetObject",
    "Resource": "arn:aws:s3:::dev-agency-website-s3bucketforwebsitecontent-11u56g1n9u9oo/*",
    "Condition": {
        "StringNotLike": {
            "aws:Referer": "79011a81-c048-4877-84f4-efe9577d7250"
        }
    }
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

    IFS=$'\r\n' GLOBIGNORE='*' rules=($(cat routing-rules/routing-rules.txt)) 

    for rule in "${rules[@]}"
    do
        components=($(echo $rule | tr " " "\r\n"))
        target="${components[1]}"
        redirect_location="${components[2]}"
        # echo "target=${target}, redirect_location=${redirect_location}"

        create_routing_rule "${bucket}" "${prefix}" "${target}" "${redirect_location}"
    done
}

create_routing_rules "dev-agency-website-s3bucketforwebsitecontent-1fbv8htrn7nna" "v0.0.1"
```
