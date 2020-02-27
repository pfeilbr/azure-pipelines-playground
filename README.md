# azure-pipelines-playground

learn [azure pipelines](https://docs.microsoft.com/en-us/azure/devops/pipelines/?view=azure-devops)

## Running

```sh
# provision aws resources
chmod +x scripts/provision.sh    
./scripts/provision.sh

# update pipeline variables with the following stack outputs
#  written to ./tmp/${STACK_NAME}-outputs.json
# `AccessKey -> AWS_ACCESS_KEY_ID, SecretKey -> AWS_SECRET_ACCESS_KEY, REGION, STACK_NAME`

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