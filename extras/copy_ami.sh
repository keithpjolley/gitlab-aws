#!/bin/sh
#
# kjolley
# This is terrible.

SOURCE_AMI_ID="ami-03e3f3c0654a308fd"
SOURCE_AMI_REGION="us-west-2"
SOURCE_AMI_OWNER_ID="842937609224"
SOURCE_AMI_INSTANCE="Replicant_Zero"
DESTINATION_AMI_NAME="gitlab_application_server_ami"
DESTINATION_DESCRIPTION="Gitlab Application Clone"

home_region="$(aws configure list  | awk '$1=="region"{print $2}')"

for region in $(aws ec2 describe-regions --output text | awk '{print $NF}' | grep -v "${home_region}")
do
    ami_id="$(aws ec2 copy-image                    \
        --source-image-id "${SOURCE_AMI_ID}"        \
        --name "${DESTINATION_AMI_NAME}"            \
        --source-region "${SOURCE_AMI_REGION}"      \
        --description "${DESTINATION_DESCRIPTION}"  \
        --region "${region}"                        \
    | tr -d '"'                                     \
    | awk '$1=="ImageId:"{print $2}')"
    echo "${region} ${ami_id}"
done
echo "${SOURCE_AMI_REGION}" "${SOURCE_AMI_ID}"
