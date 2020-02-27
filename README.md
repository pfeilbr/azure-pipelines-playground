# azure-pipelines-playground

learn [azure pipelines](https://docs.microsoft.com/en-us/azure/devops/pipelines/?view=azure-devops)

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