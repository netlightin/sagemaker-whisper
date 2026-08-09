#!/bin/bash

set -e

# Set the AWS region
REGION="eu-west-1"

# Define tag values for the security groups
SG_SAGEMAKER_NAME="steep-hill-sagemaker-sg"
SG_ECS_NAME="steep-hill-ecs-sg"
SG_ALB_NAME="steep-hill-alb-sg"

# Function to get Security Group ID by tag:Name value
get_sg_id_by_tag() {
    NAME=$1
    aws ec2 describe-security-groups \
        --region "$REGION" \
        --filters "Name=tag:Name,Values=$NAME" \
        --query "SecurityGroups[0].GroupId" \
        --output text
}

echo "# STEP 1: Find and delete ENIs attached to sagemaker SG"

# Find Security Group ID for steep-hill-sagemaker-sg
SG_ID=$(get_sg_id_by_tag "$SG_SAGEMAKER_NAME")

if [[ "$SG_ID" == "None" || -z "$SG_ID" ]]; then
    echo "No security group found with tag Name=$SG_SAGEMAKER_NAME."
else
    echo "Found Security Group ID for sagemaker: $SG_ID"
    # Find all ENIs attached to this security group
    ENI_IDS=($(aws ec2 describe-network-interfaces \
        --filters Name=group-id,Values="$SG_ID" \
        --region "$REGION" \
        --query "NetworkInterfaces[].NetworkInterfaceId" \
        --output text))
    if [[ ${#ENI_IDS[@]} -eq 0 ]]; then
        echo "No ENIs attached to SG $SG_ID."
    else
        # Delete each ENI found
        for ENI_ID in "${ENI_IDS[@]}"; do
            echo "Deleting ENI: $ENI_ID"
            aws ec2 delete-network-interface --network-interface-id "$ENI_ID" --region "$REGION"
        done
    fi
fi

echo "# STEP 2: Delete sagemaker security group"

if [[ "$SG_ID" == "None" || -z "$SG_ID" ]]; then
    echo "Can't delete sagemaker security group; not found."
else
    aws ec2 delete-security-group --group-id "$SG_ID" --region "$REGION" \
        && echo "Deleted $SG_SAGEMAKER_NAME." \
        || echo "Failed to delete $SG_SAGEMAKER_NAME."
fi

echo "# STEP 3: Delete ecs security group"

SG_ID_ECS=$(get_sg_id_by_tag "$SG_ECS_NAME")
if [[ "$SG_ID_ECS" == "None" || -z "$SG_ID_ECS" ]]; then
    echo "Can't delete ecs security group; not found."
else
    aws ec2 delete-security-group --group-id "$SG_ID_ECS" --region "$REGION" \
        && echo "Deleted $SG_ECS_NAME." \
        || echo "Failed to delete $SG_ECS_NAME."
fi

echo "# STEP 4: Delete alb security group"

SG_ID_ALB=$(get_sg_id_by_tag "$SG_ALB_NAME")
if [[ "$SG_ID_ALB" == "None" || -z "$SG_ID_ALB" ]]; then
    echo "Can't delete alb security group; not found."
else
    aws ec2 delete-security-group --group-id "$SG_ID_ALB" --region "$REGION" \
        && echo "Deleted $SG_ALB_NAME." \
        || echo "Failed to delete $SG_ALB_NAME."
fi

echo "# Script complete!"