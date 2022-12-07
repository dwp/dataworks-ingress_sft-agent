# dataworks-ingress-sft-agent

## DataWorks ingress sft agent Docker image

This repo contains Makefile, and Dockerfile to fit the standard pattern.
This repo is a base to create new Docker image repos, adding the githooks submodule, making the repo ready for use.

After cloning this repo, please run:  
`make bootstrap`


## s3fs

DataWorks ingress sft agent image mounts the stage bucket as a volume to the container, so that when the file has received to the mount directory in the container it also persists on S3.

This requires three run time variables
```
STAGE_BUCKET: bucket id where file will be stored
MNT_POINT: container directory where the bucket will be mounted
KMS_KEY_ARN: the encryption key of the stage bucket to write files

```

## Tests

The tests for this image are embedded in the [@data-ingress](https://github.com/dwp/dataworks-behavioural-framework/blob/master/src/features/data-ingress.feature) feature in dataworks-behavioural-framework.

### Trend micro test

When the following conditions are true, the Trend Micro test runs and an Eicar test file is created, detected and removed.

```
TEST_TREND_MICRO_ENV == 'development' | 'qa'
TEST_TREND_MICRO_ON == 'ci'
TYPE == 'receiver'
```
