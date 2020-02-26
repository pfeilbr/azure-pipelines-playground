# azure-pipelines-playground

learn [azure pipelines](https://docs.microsoft.com/en-us/azure/devops/pipelines/?view=azure-devops)

## Running

```sh
# provision aws resources
chmod +x scripts/provision.sh    
./scripts/provision.sh

# trigger a pipeline run via a tag
TAG_NAME="v0.0.5"
git tag -a "${TAG_NAME}" -m "releasing version ${TAG_NAME}"
git push origin "${TAG_NAME}"

```