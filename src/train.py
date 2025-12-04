# ---------------------------------------------------- #
# src/train.py: minimal model training code
# ---------------------------------------------------- #

# This file creates and trains our super simple model
# It's intentionally minimal to focus on infrastructure, not ML

import json
import pickle
import numpy as np
from datetime import datetime

def create_dummy_data():
    """Create tiny dataset - just 10 points"""
    # X = input values (1 through 10)
    X = np.array([[1], [2], [3], [4], [5], [6], [7], [8], [9], [10]])
    # y = output values (2, 4, 6... it's just y = 2x)
    y = np.array([2, 4, 6, 8, 10, 12, 14, 16, 18, 20])  # Simple y = 2x linear model
    return X, y

def train_model():
    """Train the world's simplest model"""
    print("Starting training...")
    
    # Get data
    X, y = create_dummy_data()  # Get our tiny dataset
    
    # "Train" model (just calculate slope and intercept)
    # Using numpy's polyfit for simplicity
    model_params = np.polyfit(X.flatten(), y, 1)  # Linear fit (degree 1 polynomial)
    
    # Package model as dictionary with metadata
    model = {
        'slope': float(model_params[0]),      # Convert numpy type to Python float
        'intercept': float(model_params[1]),  # y = slope*x + intercept
        'trained_at': datetime.now().isoformat(),  # Timestamp for tracking
        'version': '1.0.0'                    # Version for model management
    }
    
    # Save model
    with open('/tmp/model.pkl', 'wb') as f:  # 'wb' = write binary
        pickle.dump(model, f)  # Serialize model to binary format
    
    print(f"Model trained: y = {model['slope']}x + {model['intercept']}")
    print("Model saved to /tmp/model.pkl")
    
    # Also save as JSON for easier debugging
    with open('/tmp/model.json', 'w') as f:
        json.dump(model, f, indent=2)  # Human-readable format
    
    return model

if __name__ == "__main__":
    train_model()  # Run training when script is executed directly