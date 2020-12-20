# springboot-ecs-cfn
A basic Springboot, ECS application using Cloudformation template


## Dev tools required
1. Spring Tool Suite(STS)/ Eclipse/ VScode
2. Java 8 or above
3. Docker
4. AWS CLI 2

## Summary 
- Create a basic hello-world springboot application.
- Enable springboot actuator for health check.
- Write a simple Dockerfile to create hello-world Docker image.
- Integrate Docker image creation using maven plugin.
- Create a ECR repo in AWS, publishing Docker image using maven goals.
- Create a AWS ECS cluster for hello-world application using CloudFormation template.
- Automate the CloudFormation deployment using shell scrip & AWS CLI.
