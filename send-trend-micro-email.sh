email_send_from=$(aws secretsmanager get-secret-value --secret-id ${TREND_MICRO_SECRET_NAME} --query SecretString --output text | jq .test_notification_email_send_from | tr -d '"')
email_send_to=$(aws secretsmanager get-secret-value --secret-id ${TREND_MICRO_SECRET_NAME} --query SecretString --output text | jq .test_notification_email_send_to | tr -d '"')

echo '
{
 "ToAddresses":  ["'${email_send_to}'"],
 "CcAddresses":  [],
 "BccAddresses": []
}' >> destination.json


echo '
{
 "Subject": {
     "Data": "DWX testing - Trend Micro",
     "Charset": "UTF-8"
 },
 "Body": {
     "Text": {
         "Data": "Hello, A trend micro test is due to run in the next few minutes. Please expect a notification generated by a test virus called data_ingress_eicar.txt. This can be ignored as it has been generated for testing purposes. If you have any questions on this, please reach out to '${email_send_from}'.",
         "Charset": "UTF-8"
     }
  }
}' >> message.json

cat message.json
cat destination.json
echo $email_send_from
aws ses send-email --from $email_send_from --destination file://destination.json --message file://message.json
