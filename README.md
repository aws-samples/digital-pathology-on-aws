## Digital Pathology on AWS


### Deploy Open Source [OMERO](https://www.openmicroscopy.org/omero/) on AWS

[OMERO deployment](https://github.com/ome/omero-deployment-examples) is a typical three tier Web application. OMERO web and server are containerized and can run on [AWS ECS](https://aws.amazon.com/ecs). The data is stored in the [AWS EFS](https://aws.amazon.com/efs/) mounted to OMERO server and the [AWS RDS](https://aws.amazon.com/rds/) PostgreSQL database. 


#### Pre-requisite

First create the network infrastructure. One way to do it is to deploy using [this CloudFormation template](https://docs.aws.amazon.com/codebuild/latest/userguide/cloudformation-vpc-template.html), which will create one [AWS VPC](https://aws.amazon.com/vpc/), two public subnets and two private subnets. If you want to add [VPC flow logs](https://docs.aws.amazon.com/vpc/latest/userguide/flow-logs.html), you can deploy [the network infrastructure CloudFormation template](https://github.com/aws-samples/digital-pathology-on-aws/blob/main/OMERO-cloudformation-templates/OMERONetworkInfra.yaml) in this repository and select true for AddVPCFlowLog parameter.

If you have registered or transfer your domain to AWS Route53, you can use the associated Hosted zones to [automate the DNS validatition for the SSL certificate](https://aws.amazon.com/blogs/security/how-to-use-aws-certificate-manager-with-aws-cloudformation/) issued by [AWS Certificate Manager (ACM)](https://aws.amazon.com/certificate-manager/). It is noteworthy the Route53 domain and associated public Hosted zone should be on the same AWS account as the ACM that issues SSL certificate, in order to automate the DNS validation. ACM will create a validation CNAME record in the public Hosted zone. This DNS validated public certificate can be used for [TLS termination for Applicaton Load Balancer](https://docs.aws.amazon.com/elasticloadbalancing/latest/application/create-https-listener.html)


#### Deploy OMERO Stack

The diagram of Architecture is here:

![arch](Figures/omero-on-aws-ha.jpg)

Current OMERO server only support one writer per mounted network share file. To avoid a race condition between the two instances trying to own a lock on the network file share, we will deploy one read+write OMERO server and one read only OMERO server in the following CloudFormation templates using this 1-click deployment:  
[![launchstackbutton](Figures/launchstack.png)](https://console.aws.amazon.com/cloudformation/home?region=us-east-1#/stacks/create/template?stackName=omerostack&templateURL=https://omero-on-aws.s3-us-west-1.amazonaws.com/OMEROstackTLS_RW_RO.yml)  

which will deploy two nested CloudFormation templates, one for storage (EFS and RDS) and one for ECS containers (OMERO web and server). It also deploys a certificate for TLS termination at Application Load Balancer. Majority of parameters already have default values filled and subject to be customized. VPC and Subnets are required, which can be obtained from pre-requisite deployment. It also requires the Hosted Zone ID and fully qualifed domain name in [AWS Route53](https://aws.amazon.com/route53/), which will be used to validate SSL Certificate issued by [AWS ACM](https://aws.amazon.com/certificate-manager/). 

If you do not need the redundency for read only OMERO server, you can deploy a single read+write OMERO server using this 1-click deployment:  
[![launchstackbutton](Figures/launchstack.png)](https://console.aws.amazon.com/cloudformation/home?region=us-east-1#/stacks/create/template?stackName=omerostack&templateURL=https://omero-on-aws.s3-us-west-1.amazonaws.com/OMEROstackTLS_RW.yml)  

Even though the OMERO server is deployed in single instance, you can achieve the Hight Availability (HA) deployment of OMERO web and PostgreSQL database. You have option to deploy the OMERO containers on ECS Fargate or EC2 launch type.

If you do not have registered domain and associated hosted zone in AWS Route53, you can deploy the following CloudFormation stacks and access to OMERO web through Application Load Balancer DNS name without TLS termination using this 1-click deployment:  
[![launchstackbutton](Figures/launchstack.png)](https://console.aws.amazon.com/cloudformation/home?region=us-east-1#/stacks/create/template?stackName=omerostack&templateURL=https://omero-on-aws.s3-us-west-1.amazonaws.com/OMEROstack_RW.yml)


#### Run OMERO Client on EC2

After deploying the stack, you can launch a EC2 instance and run omero client CLI to import images on that instance. 

First find the EC2 AMI using the following mapping:
|AWS Region|AMIID|
| ----------- | ----------- |
|us-east-1|ami-0c1f575380708aa63|
|us-east-2|ami-015a2afe7e1a8af56|
|us-west-1|ami-032a827d612b78a50|
|us-west-2|ami-05edb14e89a5b98f3|
|ap-northeast-1|ami-06ee72c3360fd7fad|
|ap-northeast-2|ami-0cfc5eb79eceeeec9|
|ap-south-1|ami-078902ae8103daac8|
|ap-southeast-1|ami-09dd721a797640468|
|ap-southeast-2|ami-040bd2e2325535b3d|
|ca-central-1|ami-0a06b44c462364156|
|eu-central-1|ami-09509e8f8dea8ab83|
|eu-north-1|ami-015b157d082fd4e0d|
|eu-west-1|ami-0489c3efb4fe85f5d|
|eu-west-2|ami-037dd70536680c11f|
|eu-west-3|ami-0182381900083ba64|
|sa-east-1|ami-05313c3a9e9148109|

Or following [the instruction](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/finding-an-ami.html) here to find the current Amazon Linux 2 AMI.

Then follow [this intruction](https://docs.aws.amazon.com/cli/latest/userguide/cli-services-ec2-instances.html) to create new EC2 instance in one of public subnets in the same VPC, with same OmeroSecurityGroup:

```
aws ec2 run-instances --image-id <AMI ID> --count 1 --instance-type t2.micro --key-name sharedaccount2400 --security-group-ids <OmeroSecurityGroup ID> --subnet-id <Public Subnet ID> --profile <aws cli profile>
```

To import microscopic images to OMERO server, you can connect to the EC2 instance using SSH client (login as ec2-user) or Session Manager (login as ssm-user). Once connected, run the following scripts on the EC2 instance to install [AWS CLI](https://aws.amazon.com/cli/), [Amazon Corretto 11](https://docs.aws.amazon.com/corretto/latest/corretto-11-ug/what-is-corretto-11.html), and [omero-py](https://docs.openmicroscopy.org/omero/5.6.0/developers/Python.html):  

``` 
sudo yum install -y aws-cfn-bootstrap bzip2 unzip telnet
sudo yum install java-11-amazon-corretto-headless -y
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"  
unzip awscliv2.zip  
sudo ./aws/install 
curl -LO https://anaconda.org/anaconda-adam/adam-installer/4.4.0/download/adam-installer-4.4.0-Linux-x86_64.sh  
bash adam-installer-4.4.0-Linux-x86_64.sh -b -p ~/adam  
echo -e '\n# Anaconda Adam\nexport PATH=~/adam/bin:$PATH' >> ~/.bashrc 
source ~/.bashrc  
conda install -c anaconda libstdcxx-ng -y 
conda install -c anaconda libgcc-ng -y  
conda create -n myenv -c ome python=3.6 bzip2 expat libstdcxx-ng openssl libgcc zeroc-ice36-python omero-py -y   
source activate myenv
```

You can also perform the installation on the EC2 instance using [AWS EC2 user data shell scripts](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/user-data.html).

You can download image from AWS S3 using command:  
`aws s3 cp s3://xxxxxxxx.svs .`

and then use [OMERO client CLI](https://docs.openmicroscopy.org/omero/5.6.1/users/cli/index.html) on the EC2 instance to [import the image to OMERO](https://docs.openmicroscopy.org/omero/5.4.8/users/cli/import.html):  

`omero login`  

The omero server container instance has been assigned with a private IP address by [awsvpc network model](https://docs.aws.amazon.com/AmazonECS/latest/developerguide/task-networking.html) in this deployment. The IP address can be found on AWS console ECS Cluster => Task => Task detail page:  
<img src="Figures/ecs-task-omero-server.png" width="500">
<img src="Figures/omero-server-ip.png" width="500">

The default port number is 4064, and default username (root) and password (omero) for OMERO are used here.

Once you login, you can import whole slide images, like:  

`omero import ./xxxxxx.svs`




#### Clean up the deployed stack

1. If you deployed with SSL certificate, go to the HostedZone in Route53 and remove the validation record that route traffic to _xxxxxxxx.xxxxxxxx.acm-validations.aws.
2. Empty and delete the S3 bucket for Load Balancer access log (LBAccessLogBucket in the template) before deleting the OMERO stack
3. Manually delete the EFS file system and RDS database. By default the storage retain after the CloudFormation stack is deleted.


#### Reference 

The following information was used to build this solution:
1. [OMERO Docker](https://github.com/ome/docker-example-omero)
2. [OMERO deployment examples](https://github.com/ome/omero-deployment-examples)
3. [Deploying Docker containers on ECS](https://docs.docker.com/cloud/ecs-integration/)
4. [Tutorial on EFS for ECS EC2 launch type](https://docs.aws.amazon.com/AmazonECS/latest/developerguide/tutorial-efs-volumes.html).  
5. [Blog post on EFS for ECS Fargate](https://aws.amazon.com/blogs/aws/amazon-ecs-supports-efs/).  
6. [Blog post on EFS as Docker volume](https://aws.amazon.com/blogs/compute/amazon-ecs-and-docker-volume-drivers-amazon-ebs/)



## Security

See [CONTRIBUTING](CONTRIBUTING.md#security-issue-notifications) for more information.

## License

This library is licensed under the MIT-0 License. See the LICENSE file. 

### Disclaimer

This deployment was built based on the [open source version of OMERO](https://www.openmicroscopy.org/licensing/). OMERO is licensed under the terms of the GNU General Public License (GPL) v2 or later. Please note that by running Orthanc under GPLv2, you consent to complying with any and all requirements imposed by GPLv2 in full, including but not limited to attribution requirements. You can see a full list of requirements under [GPLv2](https://opensource.org/licenses/gpl-2.0.php).


