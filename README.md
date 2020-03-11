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
1. *(optional)* update redirect rules in [`routing-rules/routing-rules.txt`](routing-rules/routing-rules.txt)
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
    * S3 bucket(s) for static content (staging + production)
    * CloudFront distribution(s) (staging + production)
    * lambda@edge function for basic auth for staging site
    * aws secrets manager secret (json doc) to store basic auth users
    * S3 bucket for CloudFront access logs
    * SSL Certificate (ACM)
    * route53 root domain ALIAS record to CloudFront distribution
    * route53 **staging** and **www** CNAME records to CloudFront distribution
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

* add API origin to CF distribution for requests to /api/* path
    * precedence to 1, forward query strings, cookies, all all HTTP methods
    * [How to use API Gateway with CloudFront](https://advancedweb.hu/how-to-use-api-gateway-with-cloudfront/)
* route53 CNAME record to point directly to S3 bucket website domain.  used to troubleshoot/bypass cache issues.
    * e.g. https://bucket.mysite.com -> https://bucket.s3-website-us-east-1.amazonaws.com
    * research basic auth options
        * ok not to have basic auth?
* create IAM policy and role for resource provisioning
    * look at CloudFormation | Stack | Resources view for resource types
    * specify resource name prefix and suffix as variable to allow for change
    * specify role-arn for cloudformation cli
* more reliable method of picking the origin path to update since there are two origins

## Completed / Cancelled

* add staging CloudFront distribution
    * options
        * separate bucket s3://stage s3://prod
        * single bucket with prefix s3://bucket/stage/* s3://bucket/prod/*
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

# on tag
BUILD_SOURCEBRANCHNAME=v0.0.1
BUILD_SOURCEBRANCH=refs/tags/v0.0.1
BUILD_SOURCEVERSION=f302ed7e007e57c118a8835f378ddd04f63e105c
BUILD_SOURCEVERSIONMESSAGE=output env variables

# on develop branch
BUILD_SOURCEBRANCHNAME=develop
BUILD_SOURCEBRANCH=refs/heads/develop
BUILD_SOURCEVERSION=e59a3dfea5bd88be3808f46b48da7ddd83e8b809
BUILD_SOURCEVERSIONMESSAGE=output env variables

# pipeline environment variables
LEIN_HOME=/usr/local/lib/lein
BUILD_QUEUEDBY=GitHub
AGENT_HOMEDIRECTORY=/home/vsts/agents/2.165.0
M2_HOME=/usr/share/apache-maven-3.6.3
BOOST_ROOT=/usr/local/share/boost/1.69.0
SYSTEM_STAGEDISPLAYNAME=__default
AGENT_VERSION=2.165.0
SYSTEM_JOBATTEMPT=1
GOROOT_1_11_X64=/usr/local/go1.11
ANDROID_HOME=/usr/local/lib/android/sdk
JAVA_HOME_11_X64=/usr/lib/jvm/zulu-11-azure-amd64
SYSTEM_TEAMFOUNDATIONSERVERURI=https://dev.azure.com/brianpfeil/
ImageVersion=20200301.1
AGENT_TOOLSDIRECTORY=/opt/hostedtoolcache
SYSTEM_DEFINITIONID=1
AGENT_DISABLELOGPLUGIN_TESTFILEPUBLISHERPLUGIN=true
LANG=C.UTF-8
AGENT_WORKFOLDER=/home/vsts/work
AZURE_EXTENSION_DIR=/opt/az/azcliextensions
SYSTEM_DEFINITIONNAME=pfeilbr.azure-pipelines-playground
AGENT_TEMPDIRECTORY=/home/vsts/work/_temp
INVOCATION_ID=71a915879cc04391a20e7d2867d21806
JAVA_HOME_12_X64=/usr/lib/jvm/zulu-12-azure-amd64
AWS_SECRET_ACCESS_KEY=***
BUILD_REQUESTEDFOR=Brian Pfeil
SYSTEM_PHASENAME=Job
ANDROID_SDK_ROOT=/usr/local/lib/android/sdk
SYSTEM_JOBIDENTIFIER=Job.__default
SYSTEM_PULLREQUEST_ISFORK=False
JAVA_HOME=/usr/lib/jvm/zulu-8-azure-amd64
SYSTEM_JOBPARALLELISMTAG=Private
DOTNET_SKIP_FIRST_TIME_EXPERIENCE=1
USER=vsts
BUILD_REASON=IndividualCI
AGENT_OS=Linux
SYSTEM_ISSCHEDULED=False
BUILD_SOURCEVERSION=f302ed7e007e57c118a8835f378ddd04f63e105c
ENDPOINT_URL_SYSTEMVSSCONNECTION=https://dev.azure.com/brianpfeil/
BUILD_SOURCEBRANCH=refs/tags/v0.0.1
GRADLE_HOME=/usr/share/gradle
SYSTEM_WORKFOLDER=/home/vsts/work
BUILD_QUEUEDBYID=a399e9b2-ba17-47ed-9005-8c263530afdf
AGENT_DISABLELOGPLUGIN_TESTRESULTLOGPLUGIN=true
AGENT_ROOTDIRECTORY=/home/vsts/work
PWD=/home/vsts/work/1/s
ImageOS=ubuntu18
HOME=/home/vsts
AGENT_ID=8
GOROOT=/usr/local/go1.12
JOURNAL_STREAM=9:31906
SYSTEM_TOTALJOBSINPHASE=1
SYSTEM_COLLECTIONURI=https://dev.azure.com/brianpfeil/
RUNNER_TOOLSDIRECTORY=/opt/hostedtoolcache
JAVA_HOME_8_X64=/usr/lib/jvm/zulu-8-azure-amd64
AGENT_OSARCHITECTURE=X64
SYSTEM_CULTURE=en-US
SYSTEM_TEAMPROJECTID=398b5300-9203-4d2c-957c-82eedb6aea92
VSTS_AGENT_PERFLOG=/home/vsts/perflog
CONDA=/usr/share/miniconda
PIPELINE_WORKSPACE=/home/vsts/work/1
GOROOT_1_13_X64=/usr/local/go1.13
BOOST_ROOT_1_69_0=/usr/local/share/boost/1.69.0
SYSTEM_JOBPOSITIONINPHASE=1
DEBIAN_FRONTEND=noninteractive
SYSTEM_JOBID=12f1170f-54f2-53f3-20dd-22fc7dff55f9
AGENT_JOBNAME=Job
AGENT_ACCEPTTEEEULA=True
SYSTEM_STAGEATTEMPT=1
SYSTEM_PIPELINESTARTTIME=2020-03-05 22:20:12+00:00
STACK_NAME=dev-agency-website
BUILD_REPOSITORY_URI=https://github.com/pfeilbr/azure-pipelines-playground
AGENT_READONLYVARIABLES=true
BUILD_REPOSITORY_PROVIDER=GitHub
SYSTEM_TASKINSTANCENAME=CmdLine
GOROOT_1_12_X64=/usr/local/go1.12
GECKOWEBDRIVER=/usr/local/share/gecko_driver
SYSTEM_PLANID=b5cbb7c3-6a1c-4c2f-85da-7cd89b56bfcc
BUILD_DEFINITIONVERSION=13
TASK_DISPLAYNAME=deploy
SYSTEM_HOSTTYPE=build
CHROMEWEBDRIVER=/usr/local/share/chrome_driver
BUILD_STAGINGDIRECTORY=/home/vsts/work/1/a
MSDEPLOY_HTTP_USER_AGENT=VSTS_1cc55890-46d6-40c1-9714-8220ddd17bd5_build_1_0
BUILD_REQUESTEDFOREMAIL=brian.pfeil@gmail.com
TF_BUILD=True
AZURE_HTTP_USER_AGENT=VSTS_1cc55890-46d6-40c1-9714-8220ddd17bd5_build_1_0
BUILD_REPOSITORY_LOCALPATH=/home/vsts/work/1/s
SYSTEM_PHASEDISPLAYNAME=Job
BUILD_REPOSITORY_NAME=pfeilbr/azure-pipelines-playground
BUILD_ARTIFACTSTAGINGDIRECTORY=/home/vsts/work/1/a
SYSTEM_TASKDEFINITIONSURI=https://dev.azure.com/brianpfeil/
BUILD_REPOSITORY_GIT_SUBMODULECHECKOUT=False
BUILD_SOURCEVERSIONAUTHOR=Brian Pfeil
SYSTEM_TASKDISPLAYNAME=deploy
SYSTEM_STAGENAME=__default
VSTS_PROCESS_LOOKUP_ID=vsts_f104e61b-5db9-493c-8204-4ffeb8973a65
BUILD_REPOSITORY_ID=pfeilbr/azure-pipelines-playground
BUILD_SOURCEVERSIONMESSAGE=output env variables
SYSTEM=build
SYSTEM_PHASEATTEMPT=1
VCPKG_INSTALLATION_ROOT=/usr/local/share/vcpkg
SYSTEM_JOBNAME=__default
REGION=us-east-1
SYSTEM_PHASEID=3a3a2a60-14c7-570b-14a4-fa42ad92f52a
AGENT_MACHINENAME=fv-az755
COMMON_TESTRESULTSDIRECTORY=/home/vsts/work/1/TestResults
agent.jobstatus=Succeeded
JAVA_HOME_7_X64=/usr/lib/jvm/zulu-7-azure-amd64
BUILD_DEFINITIONNAME=pfeilbr.azure-pipelines-playground
AWS_ACCESS_KEY_ID=AKIAXWO2SDPLDE43XM4W
SYSTEM_ARTIFACTSDIRECTORY=/home/vsts/work/1/a
SHLVL=2
BUILD_REQUESTEDFORID=5d5ba760-cdcf-6c15-8d80-c37de4cf7631
AGENT_NAME=Hosted Agent
BUILD_BUILDNUMBER=20200305.5
BUILD_SOURCEBRANCHNAME=v0.0.1
SYSTEM_JOBDISPLAYNAME=Job
BUILD_SOURCESDIRECTORY=/home/vsts/work/1/s
LEIN_JAR=/usr/local/lib/lein/self-installs/leiningen-2.9.2-standalone.jar
BUILD_BUILDURI=vstfs:///Build/Build/53
SYSTEM_SERVERTYPE=Hosted
SYSTEM_TIMELINEID=b5cbb7c3-6a1c-4c2f-85da-7cd89b56bfcc
AGENT_RETAINDEFAULTENCODING=false
SYSTEM_TASKINSTANCEID=9c939e41-62c2-5605-5e05-fc3554afc9f5
SYSTEM_DEFAULTWORKINGDIRECTORY=/home/vsts/work/1/s
AGENT_JOBSTATUS=Succeeded
ANT_HOME=/usr/share/ant
BUILD_REPOSITORY_CLEAN=False
SYSTEM_TEAMPROJECT=project01
PATH=/usr/share/rust/.cargo/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/snap/bin
SELENIUM_JAR_PATH=/usr/share/java/selenium-server-standalone.jar
CHROME_BIN=/usr/bin/google-chrome
SYSTEM_COLLECTIONID=1cc55890-46d6-40c1-9714-8220ddd17bd5
BUILD_CONTAINERID=5246219
SYSTEM_TEAMFOUNDATIONCOLLECTIONURI=https://dev.azure.com/brianpfeil/
GIT_TERMINAL_PROMPT=0
AGENT_BUILDDIRECTORY=/home/vsts/work/1
SYSTEM_STAGEID=96ac2280-8cb4-5df5-99de-dd2da759617d
SYSTEM_ENABLEACCESSTOKEN=SecretVariable
BUILD_BINARIESDIRECTORY=/home/vsts/work/1/b
BUILD_BUILDID=53

${BUILD_REPOSITORY_URI}/tree/${BUILD_SOURCEBRANCHNAME}
${BUILD_REPOSITORY_URI}/commit/${BUILD_SOURCEVERSION}

# athena create table for CloudFront logs
CREATE EXTERNAL TABLE IF NOT EXISTS default.cloudfront_logs_stagingallthecloudbits (
  `date` DATE,
  time STRING,
  location STRING,
  bytes BIGINT,
  request_ip STRING,
  method STRING,
  host STRING,
  uri STRING,
  status INT,
  referrer STRING,
  user_agent STRING,
  query_string STRING,
  cookie STRING,
  result_type STRING,
  request_id STRING,
  host_header STRING,
  request_protocol STRING,
  request_bytes BIGINT,
  time_taken FLOAT,
  xforwarded_for STRING,
  ssl_protocol STRING,
  ssl_cipher STRING,
  response_result_type STRING,
  http_version STRING,
  fle_status STRING,
  fle_encrypted_fields INT,
  c_port INT,
  time_to_first_byte FLOAT,
  x_edge_detailed_result_type STRING,
  sc_content_type STRING,
  sc_content_len BIGINT,
  sc_range_start BIGINT,
  sc_range_end BIGINT
)
ROW FORMAT DELIMITED 
FIELDS TERMINATED BY '\t'
LOCATION 's3://dev-agency-website-cloudfrontlogsbucket-jf9ykpajh7n1/cloudfront/logs/staging.allthecloudbits.com/'
TBLPROPERTIES ( 'skip.header.line.count'='2' )

# query
SELECT * FROM "default"."cloudfront_logs_stagingallthecloudbits" limit 10

```
