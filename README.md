## Deploy Springboot microservices on Amazon ECS using ECR & Fargate
<br/>
<p align="center"><img src="assets/aws.jpg" height="320" width="640"></p>


### Tools
1. Spring Tool Suite(STS)/ Eclipse/ VScode
2. Java 8 or greater
3. Maven 3.5
4. Docker
5. AWS account
6. AWS Command Line Interface (CLI)

### Follow links:

* Install AWS CLI 2 : https://docs.aws.amazon.com/cli/latest/userguide/install-cliv2.html
* Configure AWS CLI : https://docs.aws.amazon.com/cli/latest/userguide/cli-configure-quickstart.htm

### Steps 

![Image of Process flow](assets/codecommit.png)

- Create a basic hello-world springboot application.
- Enable springboot actuator for health check.
- Write a simple Dockerfile to create hello-world Docker image.
- Integrate Docker image creation using maven plugin.
- Create a ECR repo in AWS, publishing Docker image using maven goals.
- Create a AWS ECS cluster for hello-world application using CloudFormation template.
- Automate the CloudFormation deployment using shell scrip & AWS CLI.
  

### Target Architecture

![Image of Target Architecture](assets/target-arch.png)

### Amazon ECS & Farget

Amazon ECS is a highly scalable, high-performance container orchestration service that supports Docker containers and allows you to easily run and scale containerized applications on AWS. 

AWS Fargate is a compute engine for Amazon ECS that allows you to run containers without having to manage servers or clusters. 

- #### Amazon ECS 

Amazon ECS eliminates the need to install and operate your own container orchestration software, manage and scale a cluster of virtual machines, or schedule containers on those virtual machines.

- #### AWS Fargate

With the AWS Fargate compute engine, you no longer have to provision, configure, and scale clusters of virtual machines to run containers, choose server types, decide when to scale your clusters, or optimize cluster packing.  

- #### Docker

Docker is a software platform that allows you to build, test, and deploy applications quickly. Docker packages software into standardized units called containers that have everything the software needs to run, including libraries, system tools, code, and runtime. 

## AWS Cloud​Formation (Infrastructure as Code)

AWS CloudFormation enables you to create and provision AWS infrastructure deployments predictably and repeatedly. AWS CloudFormation enables you to use a template file to create and delete a collection of resources together as a single unit (a stack).

![Image of Cloudformation](https://d1.awsstatic.com/Products/product-name/diagrams/product-page-diagram_CloudFormation.ad3a4c93b4fdd3366da3da0de4fb084d89a5d761.png)
