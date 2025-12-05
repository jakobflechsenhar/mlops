# ---------------------------------------------------- #
# src/train.py: minimal model training code
# ---------------------------------------------------- #

# This file creates and trains our super simple model
# It's intentionally minimal to focus on infrastructure, not ML

# src/train.py - Updated for S3 data
import json
import pickle
import numpy as np
from datetime import datetime
import boto3
import os

s3 = boto3.client('s3')

def load_training_data():
    """Load training data from S3 or use default"""
    bucket = os.environ.get('S3_BUCKET', 'mlops-models')
    
    try:
        # Try to load data from S3
        s3.download_file(bucket, 'data/training_data.json', '/tmp/training_data.json')
        with open('/tmp/training_data.json', 'r') as f:
            data = json.load(f)
            X = np.array(data['X']).reshape(-1, 1)
            y = np.array(data['y'])
        print(f"Loaded {len(X)} data points from S3")
        
    except Exception as e:
        print(f"No S3 data found ({e}), using default dataset")
        # Default data (y = 2x)
        X = np.array([[1], [2], [3], [4], [5], [6], [7], [8], [9], [10]])
        y = np.array([2, 4, 6, 8, 10, 12, 14, 16, 18, 20])
    
    return X, y

def train_model():
    """Train model on data from S3"""
    print("Starting training...")
    
    # Load data
    X, y = load_training_data()
    
    # Train linear regression
    model_params = np.polyfit(X.flatten(), y, 1)
    
    # Calculate metrics
    predictions = model_params[0] * X.flatten() + model_params[1]
    mse = np.mean((y - predictions) ** 2)
    
    # Create model object
    model = {
        'slope': float(model_params[0]),
        'intercept': float(model_params[1]),
        'mse': float(mse),
        'training_samples': len(X),
        'trained_at': datetime.now().isoformat(),
        'version': f'1.0.{len(X)}',
        'data_stats': {
            'x_mean': float(X.mean()),
            'y_mean': float(y.mean()),
            'x_std': float(X.std()),
            'y_std': float(y.std())
        }
    }
    
    # Save model
    with open('/tmp/model.pkl', 'wb') as f:
        pickle.dump(model, f)
    
    with open('/tmp/model.json', 'w') as f:
        json.dump(model, f, indent=2)
    
    print(f"✅ Model trained: y = {model['slope']:.3f}x + {model['intercept']:.3f}")
    print(f"📊 Training samples: {model['training_samples']}")
    print(f"📈 MSE: {model['mse']:.3f}")
    
    return model

if __name__ == "__main__":
    train_model()