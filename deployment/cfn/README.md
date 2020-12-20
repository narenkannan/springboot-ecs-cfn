### Deploy in AWS ECS
###### Create new VPC, 2 public subnet and 2 private subnet
```
aws cloudformation deploy --template-file vpc.yml --stack-name TEST-VPC
```
###### Deploy application in ECS cluster
When message service container comes up, it goes and register in AWS service discovery and it can be accessed using 'messageservice.messagesvcnamespace' in the same VPC.
```
aws cloudformation deploy --template-file service.yml --stack-name HZ-SERVICE 
    --capabilities CAPABILITY_NAMED_IAM 
    --parameter-overrides VpcId=vpc-******* 
    PublicSubnetList="subnet-************, subnet-***********" 
    PrivateSubnetList="subnet-***********, subnet-***********"
```

### Test
###### Hazelcast Management Center
```
http://HZ-APP-ALB-*******.us-east-1.elb.amazonaws.com/hazelcast-mancenter/
```
###### Hazelcast Client
Health Check
Save Token
```
curl -X POST \
  http://HZ-APP-ALB-*******.us-east-1.elb.amazonaws.com/api/v1/hz/client/tokens \
  -H 'Content-Type: application/json' \
  -d '{
	"username": "Foo Bar",
	"token": "a129837-xcv2422-fdd943875"
}'
```
Get Token
```
curl -X GET \
  'http://HZ-APP-ALB-*******.us-east-1.elb.amazonaws.com/api/v1/hz/client/tokens?username=Foo%20Bar'
```