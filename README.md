# Terraform Web Server Cluster with AWS WAF, VPC, ALB and ASG w/ CloudFront

This [Terraform](https://www.terraform.io/) config sets up a VPC, public subnets, Application Load Balancer (ALB), Auto Scaling Group (ASG), and other networking components along with AWS WAF rules to deploy and securely host a web application. 

It creates an ALB, ASG with Launch Template, VPC, subnets, route tables, security groups, IAM roles & policies. There is also a CloudFront CDN distribution in front of the ALB origin servers for global content delivery.

## Purpose

This Terraform configuration sets up a scalable and secure web application infrastructure on AWS.

Some key benefits:

- Uses VPC, subnets, security groups, and route tables to create an isolated and secured network environment.

- Deploys an Application Load Balancer (ALB) with auto-scaling group of EC2 instances to provide scalable and high availability web servers.

- Uses a CloudFront CDN distribution in front of the ALB origin for performance, caching, and additional security. 

- Leverages AWS WAF rules to protect against common attacks like SQL injection, cross-site scripting, geo blocking, and DDoS.

- Templates and variables are used for reusability and customization.

Feel free to update the user data script for the ASG Launch Template based on your use cases.

## Prerequisites

- You must have [Terraform](https://www.terraform.io/) installed on your computer.
- AWS CLI v2
- [AWS (Amazon Web Services)](http://aws.amazon.com/) account and its credentials set up for your AWS CLI.

## Installation

1. Install [Terraform](https://www.terraform.io/downloads.html), if you don't already have it.

2. Configure your AWS access keys in your AWS CLI, if you haven't yet:

    ```bash
    aws configure
    ```

3. Clone this repository:

    ```bash
    git clone https://github.com/Rammina/terraform-webserver-cluster-aws-waf-nacl.git
    ```

4. Navigate into the repository directory:

    ```bash 
    cd terraform-webserver-cluster-aws-waf-nacl
    ```

## Usage

1. Install the plugins and modules needed for the configuration:

    ```bash
    terraform init
    ```

2. Check for syntax errors and missing variables/resources:

    ```bash
    terraform validate
    ```

3. Show the infrastructure changes to be made if the configuration is applied:

    ```bash
    terraform plan
    ```

4. Customize the setup by modifying the project files as needed. Feel free to update it according your needs.

5. Apply the changes to deploy the infrastructure - this provisions the resources specified in the configuration:

    ```bash
    terraform apply
    ```

6. When you are finished with the infrastructure and no longer need it, you can destroy it:

    ```bash
    terraform destroy
    ```

    This removes all provisioned infrastructure resources.

7. In between `terraform apply` and `terraform destroy`, you can modify Terraform files as needed and rerun steps 2-4 to incrementally update your infrastructure.
