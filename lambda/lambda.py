import json
import boto3
import pprint
import random

def lambda_handler(event,context):
    client = boto3.client('ssm')
    
    test=event['queryStringParameters']['ParameterName'] # variable to storing ParameterName
    val= str(random.randint(10001,100001)) # variable for fetching random value within given range
    
    body = {
        "Congratulations! Your Parameter is sucessfully created": "" , 'ParameterName': str(test), 'ParameterValue':val}
    
    # Fetching existing parameter in Parameter Store using get_parameter method
    try:
        if event['httpMethod']=='GET' and test:
            resp = client.get_parameter( Name = test, WithDecryption=True )
            body = {'ParameterName': test, 'ParameterValue': val}
     
    # Creating new parameter in Parameter Store using put_parameter method        
    except Exception as e:
        client.put_parameter(
       Name =test, Description="A test parameter", Value=val, Type="SecureString"
    )

        pass
    response = {'statusCode': 200, 'body': json.dumps(body) }
    return response
    