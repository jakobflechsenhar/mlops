# ---------------------------------------------------- #
# src/predict.py: lambda inference code
# ---------------------------------------------------- #

# This file runs inside AWS Lambda to serve model predictions
# It's the "API" that users will call to get predictions

import json
import pickle
import boto3
import os
from typing import Dict, Any

# Initialize S3 client
s3 = boto3.client('s3') # Creates connection to AWS S3 storage

# Global model variable (loaded once during Lambda cold start)
MODEL = None # Global to avoid reloading model on every request (saves time/money)

def load_model():
    """Load model from S3"""
    global MODEL # Use the global MODEL variable
    
    if MODEL is None: # Only load if not already loaded (Lambda reuses containers)
        print("Loading model from S3...")
        bucket = os.environ.get('MODEL_BUCKET', 'mlops-models') # Get bucket name from Lambda environment
        key = os.environ.get('MODEL_KEY', 'models/model.pkl') # Get file path from Lambda environment
        
        # Download model to /tmp
        s3.download_file(bucket, key, '/tmp/model.pkl') # Lambda only allows writing to /tmp
        
        # Load model
        with open('/tmp/model.pkl', 'rb') as f:
            MODEL = pickle.load(f) # Deserialize the model from pickle format
        
        print(f"Model loaded: {MODEL}")
    
    return MODEL

def lambda_handler(event: Dict[str, Any], context: Any) -> Dict[str, Any]:
    """Lambda handler for predictions"""
    # This is the main entry point - AWS Lambda calls this function
    try:
        # Load model
        model = load_model() # Get our trained model
        
        # Parse input
        body = json.loads(event.get('body', '{}')) # Extract JSON from HTTP request body
        x_value = float(body.get('x', 0)) # Get 'x' value, default to 0
        
        # Make prediction (y = mx + b)
        prediction = model['slope'] * x_value + model['intercept'] # Simple linear equation
        
        # Return response
        return {
            'statusCode': 200, # HTTP success code
            'headers': {
                'Content-Type': 'application/json'
            },
            'body': json.dumps({ # Convert Python dict to JSON string
                'prediction': prediction,
                'model_version': model.get('version', 'unknown'),
                'input': x_value
            })
        }
        
    except Exception as e:
        print(f"Error: {str(e)}")
        return {
            'statusCode': 500, # HTTP error code
            'body': json.dumps({
                'error': str(e)
            })
        }