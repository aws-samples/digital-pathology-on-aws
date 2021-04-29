#!/usr/bin/env bash

profilename=$1
profilename=${profilename:-default}
echo "AWS Profile name is: $profilename"

# This script shows how to build the Docker image and push it to ECR to be ready for use by SageMaker.

# The argument to this script is the image name. This will be used as the image on the local
# machine and combined with the account and region to form the repository name for ECR.
image_name=omero-web-plugins

# Get the account number associated with the current IAM credentials
account=$(aws sts get-caller-identity --query Account --output text --profile $profilename)

# Get the region defined in the current configuration (default to us-east-1 if none defined)
region=$(aws configure get region --profile $profilename)
region=${region:-us-east-1}
echo "AWS Profile region is: $region"


fullname="${account}.dkr.ecr.${region}.amazonaws.com/${image_name}:latest"
echo "ECR image fullname is: $fullname"

# If the repository doesn't exist in ECR, create it.
aws ecr describe-repositories --repository-names "${image_name}" --profile $profilename > /dev/null 2>&1

if [ $? -ne 0 ]
then
    aws ecr create-repository --repository-name "${image_name}" --profile $profilename > /dev/null
fi

# Get the login command from ECR and execute it directly
aws ecr get-login-password --region ${region} --profile $profilename | docker login --username AWS --password-stdin ${account}.dkr.ecr.${region}.amazonaws.com

# Build the docker image locally with the image name and then push it to ECR with the full name.
docker build  -t ${image_name} . --build-arg REGION=${region}
docker tag ${image_name} ${fullname}

docker push ${fullname}