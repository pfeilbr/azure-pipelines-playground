# azure-pipelines-playground

learn [azure pipelines](https://docs.microsoft.com/en-us/azure/devops/pipelines/?view=azure-devops)

## Description

Pipeline performs an atomic deploy of static content from a github repo to a static site (CloudFront + S3 when) a tag (release)
is applied to the repo

## Files

* [`cfn-templates/automation-stack.yaml`](cfn-templates/automation-stack.yaml) - CloudFormation stack for provisioning AWS resources.
    * S3 bucket for static content
    * CloudFront distribution
    * SSL Certificate (ACM)
    * route53 root domain ALIAS record to CloudFront distribution
    * route53 www CNAME record to CloudFront distribution
    * IAM user for CI/CD automation used by the azure pipeline
* [`public`](public) - static web content
* [`scripts/provision.sh`](scripts/provision.sh) - provisions AWS resources
* [`tmp/automation-stack-outputs.json`](tmp/automation-stack-outputs.json) - stack outputs stored here.  file gets created when stack is provisioned.
* [`scripts/tag-and-trigger-publish.sh`](scripts/tag-and-trigger-publish.sh) - tags and pushes the tag to github to trigger the publish pipeline
* [`scripts/publish.sh`](scripts/publish.sh) - publishes a new version of the static site based on git tag.  this is used by pipeline
* [`azure-pipelines.yml`](azure-pipelines.yml) - pipeline definition that get triggered on tag to publish to site


## Running

```sh
# you must create route 53 hosted zone first
# update `DomainName` parameter in `scripts/provision.sh` with the hosted zone name

# provision aws resources
chmod +x scripts/provision.sh    
./scripts/provision.sh

# update pipeline variables with the following stack outputs
#  written to ./tmp/${STACK_NAME}-outputs.json
# `REGION, STACK_NAME, AccessKey -> AWS_ACCESS_KEY_ID, SecretKey -> AWS_SECRET_ACCESS_KEY`

# trigger a pipeline run via a tag
chmod +x scripts/tag-and-trigger-publish.sh
./scripts/tag-and-trigger-publish.sh

# delete all remote tags
git tag -l | xargs -n 1 git push --delete origin

# delete all local tags
git tag | xargs git tag -d
```

---

## Screenshots

**Pipeline Variables**

![](https://www.evernote.com/l/AAHE5oOGeN9Kv7oZa-EDbz0NwbJwlITnmBkB/image.png)

---

## Notes

* pipeline is running in azure DevOps tied to personal gmail account