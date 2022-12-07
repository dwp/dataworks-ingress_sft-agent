# DataWorks ingress SFT agent

Alpine Docker image to receive files using the [SFT Java agent](https://dwpdigital.atlassian.net/wiki/spaces/SFT/pages/113836037260/SFT+Agent+Documentation).

## DataWorks ingress sft agent Docker image

This repo contains Makefile, and Dockerfile to fit the standard pattern.
After cloning this repo, please run:  
`make bootstrap`


## s3fs

DataWorks ingress SFT agent mounts the stage bucket as a volume in the container, so that when the file has received to the mount directory in the container it also persists on S3. This is done by using the [s3fs|https://github.com/s3fs-fuse/s3fs-fuse] tool.

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

### SFT test

This test runs (only in dev and qa) whenever thera are two container instances available to run SFT sender and receiver. The sender will create a file in the directory that is then sent to the receiver endpoint including instance IP and local directory as defined in the [e2e congif](https://github.com/dwp/dataworks-aws-data-ingress/blob/master/terraform/data-ingress-sft-task/sft_config/agent-application-config-receiver-e2e.tpl) . The test passes if the file is renamed and is present on S3 stage bucket.


