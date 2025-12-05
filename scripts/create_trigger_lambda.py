# ---------------------------------------------------- #
# scripts/create_trigger_lambda.py
# ---------------------------------------------------- #

#!/usr/bin/env python3
import zipfile
import os

# Create Lambda function code
lambda_code = '''
import json
import boto3
import os

codebuild = boto3.client('codebuild')
s3 = boto3.client('s3')

def handler(event, context):
    """Triggered when new data is uploaded to S3"""
    
    # Get the uploaded file info
    for record in event['Records']:
        bucket = record['s3']['bucket']['name']
        key = record['s3']['object']['key']
        
        print(f"New data uploaded: {bucket}/{key}")
        
        # Only process CSV files in new-data/ folder
        if key.startswith('new-data/') and key.endswith('.csv'):
            # Process the data
            process_new_data(bucket, key)
            
            # Trigger CodeBuild to retrain
            project = os.environ['CODEBUILD_PROJECT']
            response = codebuild.start_build(projectName=project)
            
            print(f"Started build: {response['build']['id']}")
    
    return {'statusCode': 200}

def process_new_data(bucket, key):
    """Merge new data with existing training data"""
    
    # Download new data
    s3.download_file(bucket, key, '/tmp/new_data.csv')
    
    # Download existing data (if exists)
    training_data = []
    try:
        s3.download_file(bucket, 'data/training_data.json', '/tmp/training_data.json')
        with open('/tmp/training_data.json', 'r') as f:
            data = json.load(f)
            training_data = list(zip(data['X'], data['y']))
    except:
        print("No existing training data")
    
    # Parse new CSV data
    with open('/tmp/new_data.csv', 'r') as f:
        lines = f.readlines()[1:]  # Skip header
        for line in lines:
            x, y = line.strip().split(',')
            training_data.append((float(x), float(y)))
    
    # Save merged data
    X = [point[0] for point in training_data]
    y = [point[1] for point in training_data]
    
    merged_data = {
        'X': X,
        'y': y,
        'count': len(X)
    }
    
    with open('/tmp/training_data.json', 'w') as f:
        json.dump(merged_data, f)
    
    # Upload back to S3
    s3.upload_file('/tmp/training_data.json', bucket, 'data/training_data.json')
    
    # Archive processed file
    new_key = key.replace('new-data/', 'processed-data/')
    s3.copy_object(
        Bucket=bucket,
        CopySource={'Bucket': bucket, 'Key': key},
        Key=new_key
    )
    s3.delete_object(Bucket=bucket, Key=key)
    
    print(f"Processed {len(lines)} new data points. Total: {len(X)}")
'''

# Write the Lambda function
with open('lambda_function.py', 'w') as f:
    f.write(lambda_code)

# Create index.py that imports it
with open('index.py', 'w') as f:
    f.write('from lambda_function import handler\n')

# Zip it
with zipfile.ZipFile('lambda_trigger.zip', 'w') as z:
    z.write('lambda_function.py')
    z.write('index.py')

# Cleanup
os.remove('lambda_function.py')
os.remove('index.py')

print("Created lambda_trigger.zip")