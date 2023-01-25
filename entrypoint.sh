#!/bin/sh

set -e

echo "setting environment variables"

export HTTP_PROXY="http://${internet_proxy}:3128"
export HTTPS_PROXY="$HTTP_PROXY"
export NO_PROXY="${non_proxied_endpoints},${dks_fqdn}"
export AWS_S3_FILE_OVERWRITE=False # allows for multiple files having the same name to exist by appending a unique string at the end of any duplicate object name


if [ "${TYPE}" = receiver ] ; then
  if [ -z "${SFT_AGENT_RECEIVER_CONFIG_S3_BUCKET}" -o -z "${SFT_AGENT_RECEIVER_CONFIG_S3_PREFIX}" ]; then
    echo "container failed due to missing required env vars SFT_AGENT_RECEIVER_CONFIG_S3_BUCKET, SFT_AGENT_RECEIVER_CONFIG_S3_PREFIX"
    exit 1
  fi

  CONTAINER_ARN=$(cat "${ECS_CONTAINER_METADATA_FILE}" | jq -r '.ContainerInstanceARN')
  CONTAINER_DESCRIPTION=$(aws ecs describe-container-instances --container-instances "${CONTAINER_ARN}" --cluster data-ingress --region "${AWS_DEFAULT_REGION}")
  EC2_INSTANCE_ID=$(echo "${CONTAINER_DESCRIPTION}" | jq -r '.containerInstances[0].ec2InstanceId')
  nis=$(aws ec2 describe-network-interfaces --filters Name="attachment.instance-id",Values="${EC2_INSTANCE_ID}" | jq -r .NetworkInterfaces)
  ni_tag=di-ni-${TYPE}
  ni_tags=$(echo $nis | jq -r '.[].TagSet[].Value')
  ni_tags="$ni_tags"nonempty

  echo "looking for network interface $ni_tag"

  if [ -z "${ni_tags##*$ni_tag*}" ]; then
    echo "network interface already attached"
  else
    echo "network interface $ni_tag not present "
    echo "attaching $ni_tag as the third network interface"
    aws ec2 attach-network-interface --region "${AWS_DEFAULT_REGION}" --instance-id "${EC2_INSTANCE_ID}" --network-interface-id "${NI_ID}" --device-index 3
  fi
  S3_URI="s3://${SFT_AGENT_RECEIVER_CONFIG_S3_BUCKET}/${SFT_AGENT_RECEIVER_CONFIG_S3_PREFIX}"


elif [ "${TYPE}" = sender ] ; then
  s=180
  echo "waiting $s seconds to allow receiver agent to start"
  sleep $s
  if [ -z "${SFT_AGENT_SENDER_CONFIG_S3_BUCKET}" -o -z "${SFT_AGENT_SENDER_CONFIG_S3_PREFIX}" ]; then
    echo "container failed due to missing required env vars SFT_AGENT_SENDER_CONFIG_S3_BUCKET, SFT_AGENT_SENDER_CONFIG_S3_PREFIX"
    exit 1
  fi
  S3_URI="s3://${SFT_AGENT_SENDER_CONFIG_S3_BUCKET}/${SFT_AGENT_SENDER_CONFIG_S3_PREFIX}"

else
  echo "container failed due to TYPE must be either sender or receiver but ${TYPE} was provided"
  exit 1
fi

echo "downloading agent configurations from ${S3_URI}"
aws s3 cp "${S3_URI}/agent-config-${TYPE}.yml" "agent-config.yml"

echo "downloading sft config"
aws s3 cp "${S3_URI}/agent-application-config-${TYPE}.yml" "agent-application-config.yml"

TRUSTSTORE_PASSWORD=$(uuidgen -r)
KEYSTORE_PASSWORD=$(uuidgen -r)
KEY_STORE_PATH="/opt/data-ingress/keystore.jks"
TRUST_STORE_PATH="/opt/data-ingress/truststore.jks"

echo "retrieving acm certs"
acm-cert-retriever \
--acm-cert-arn "${acm_cert_arn}" \
--acm-key-passphrase "$KEYSTORE_PASSWORD" \
--add-downloaded-chain-to-keystore true \
--keystore-path "$KEY_STORE_PATH" \
--keystore-password "$KEYSTORE_PASSWORD" \
--private-key-alias "${private_key_alias}" \
--private-key-password "$KEYSTORE_PASSWORD" \
--truststore-path "$TRUST_STORE_PATH" \
--truststore-password "$TRUSTSTORE_PASSWORD" \
--truststore-aliases "${truststore_aliases}" \
--truststore-certs "${truststore_certs}"

cd /usr/local/share/ca-certificates/
touch data_ingress_sft_ca.pem

TRUSTSTORE_ALIASES="${TRUSTSTORE_ALIASES}"
for F in $(echo "$TRUSTSTORE_ALIASES" | sed "s/,/ /g"); do
(cat "$F.crt"; echo) >> data_ingress_sft_ca.pem;
done

cd /app
unset HTTP_PROXY
unset HTTPS_PROXY
unset NO_PROXY


if [ "${TYPE}" = receiver ] ; then
echo "mounting ${STAGE_BUCKET} bucket"
fusermount -u "${MNT_POINT}"
nohup /opt/s3fs-fuse/bin/s3fs "${STAGE_BUCKET}" "${MNT_POINT}" \
    -o ecs \
    -o endpoint="${AWS_DEFAULT_REGION}" \
    -o url="https://s3-${AWS_DEFAULT_REGION}.amazonaws.com" \
    -o use_sse=kmsid:"${KMS_KEY_ARN}" \
    -o nonempty \
    -o allow_other
echo "files currently in s3:"
sleep 5
ls "${MNT_POINT}"
fi

if [ "${TESTING_ON}" = "ci" ]  & [ "${TYPE}" = receiver ]; then
  mkdir -p /mnt/point/e2e/eicar_test
  echo 'pass' >> /mnt/trend_micro_test/pass.txt
  if [ "${ENVIRONMENT}" = "development" ]; then
  echo "creating eicar file to test trend micro identifies it as a test virus"
  echo 'X5O!P%@AP[4\PZX54(P^)7CC)7}$EICAR-STANDARD-ANTIVIRUS-TEST-FILE!$H+H*' >> /mnt/trend_micro_test/data_ingress_eicar.txt
  sleep 10
  cat /mnt/trend_micro_test/data_ingress_eicar.txt || cp /mnt/trend_micro_test/pass.txt /mnt/point/e2e/eicar_test
  sleep 10
  cp /mnt/trend_micro_test/data_ingress_eicar.txt /mnt/point/e2e/eicar_test || cp /mnt/trend_micro_test/pass.txt /mnt/point/e2e/eicar_test
  fi
  if [ "${ENVIRONMENT}" = "qa" ]; then
    echo "skipping trend micro test"
    cp /mnt/trend_micro_test/pass.txt /mnt/point/e2e/eicar_test
  fi
fi

if [ "${TYPE}" = sender ]; then
  echo "creating file that will be sent to receiver"
  echo "ab,c,de" >> /mnt/send_point/prod217.csv
fi

if [ "${TYPE}" = receiver ] ; then
  today=$(date +'%Y-%m-%d')
  FILENAME="${FILENAME_PREFIX}-$today.csv"
  sed -i "s/^\(\s*rename_replacement\s*:\s*\).*/\1$FILENAME/" agent-application-config.yml
fi

sed -i "s/^\(\s*keyStorePassword\s*:\s*\).*/\1$KEYSTORE_PASSWORD/" agent-config.yml
sed -i "s|^\(\s*keyStorePath\s*:\s*\).*|\1$KEY_STORE_PATH|" agent-config.yml
sed -i "s|^\(\s*trustStorePath\s*:\s*\).*|\1$TRUST_STORE_PATH|" agent-config.yml
sed -i "s/^\(\s*trustStorePassword\s*:\s*\).*/\1$TRUSTSTORE_PASSWORD/" agent-config.yml

echo "starting sft agent"

exec java -Djavax.net.ssl.keyStore="$KEY_STORE_PATH" -Djavax.net.ssl.keyStorePassword="${KEYSTORE_PASSWORD}" \
-Djavax.net.ssl.trustStore="$TRUST_STORE_PATH" -Djavax.net.ssl.trustStorePassword="${TRUSTSTORE_PASSWORD}" \
-Djavax.net.ssl.keyAlias="${PRIVATE_KEY_ALIAS}" -jar -Xmx12g sft-agent.jar server agent-config.yml
