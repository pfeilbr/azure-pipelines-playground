# azure-pipelines-playground

learn [azure pipelines](https://docs.microsoft.com/en-us/azure/devops/pipelines/?view=azure-devops)

## Description

Pipeline performs an atomic deploy of static content from a github repo to a static site (CloudFront + S3 when) a tag (release)
is applied to the repo

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


## Running

1. create route 53 hosted zone for your domain name (e.g. `mydomain.com`)
1. update `DOMAIN_NAME` parameter in [`scripts/provision.sh`](scripts/provision.sh) with the hosted zone name 
1. provision aws resources `./scripts/stack.sh create`
1. Check ACM to confirm Certificate validation via DNS validation has completed.  May need to add DNS validation records to route53 hosted zone.
1. update pipeline variables
    * REGION - *default is us-east-1*
    * STACK_NAME - defined in [`scripts/stack.sh`](scripts/stack.sh)
    * AWS_ACCESS_KEY_ID - `AccessKey` output in `./tmp/${STACK_NAME}-outputs.json`
    * AWS_SECRET_ACCESS_KEY - `SecretKey` output in `./tmp/${STACK_NAME}-outputs.json`
1. update `TAG_NAME` in `./scripts/tag-and-trigger-publish.sh` with your version.
1. trigger a pipeline run via a tag `./scripts/tag-and-trigger-publish.sh`.  
1. publish will run.  can take up to 20 minutes to complete due CloudFront distribution update.
1. verify updated content by visiting <https://mydomain.com> and <https://www.mydomain.com>

---

## Screenshots

**Pipeline Variables**

![](https://www.evernote.com/l/AAHE5oOGeN9Kv7oZa-EDbz0NwbJwlITnmBkB/image.png)

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
```
