# azure-pipelines-playground

learn [azure pipelines](https://docs.microsoft.com/en-us/azure/devops/pipelines/?view=azure-devops)

## Running

```sh
# provision aws resources
chmod +x scripts/provision.sh    
./scripts/provision.sh

# trigger a pipeline run via a tag
chmod +x scripts/tag-and-trigger-publish.sh
./scripts/tag-and-trigger-publish.sh
```