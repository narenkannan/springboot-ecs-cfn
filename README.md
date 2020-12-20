# Deploy Springboot microservices on Amazon ECS using Amazon ECR & AWS Fargate


## Tools
1. Spring Tool Suite(STS)/ Eclipse/ VScode
2. Java 8 or greater
3. Maven 3.5
4. Docker
5. AWS account
6. AWS Command Line Interface (CLI)

## Steps 
- Create a basic hello-world springboot application.
- Enable springboot actuator for health check.
- Write a simple Dockerfile to create hello-world Docker image.
- Integrate Docker image creation using maven plugin.
- Create a ECR repo in AWS, publishing Docker image using maven goals.
- Create a AWS ECS cluster for hello-world application using CloudFormation template.
- Automate the CloudFormation deployment using shell scrip & AWS CLI.

## Target Architecture

![Image of Target Architecture](https://github.com/narenkannan/springboot-ecs-cfn/blob/develop/assets/target-arch.png)
