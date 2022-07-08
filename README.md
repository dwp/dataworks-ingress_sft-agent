# dataworks-ingress_sft-agent

## DataWorks ingress sft agent Docker image

This repo contains Makefile, and Dockerfile to fit the standard pattern.
This repo is a base to create new Docker image repos, adding the githooks submodule, making the repo ready for use.

After cloning this repo, please run:  
`make bootstrap`


## s3fs

DataWorks ingress sft agent image mounts the stage bucket as a volume to the container.
This requires three run time variables
```
STAGE_BUCKET: bucket id
MNT_POINT: a directory on the container where the bucket will be mounted
KMS_KEY_ARN: the encryption key of the bucket

```

## Tests

### Trend micro test

When CREATE_TEST_FILES variable is set to true, a test virus file is created to verify that the agent is active.
