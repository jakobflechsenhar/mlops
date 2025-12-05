# ---------------------------------------------------- #
# README: MLOps Project
# ---------------------------------------------------- #

```
MLOps/
├── src/
│   ├── train.py           # Trains model (reads from S3 data)
│   └── predict.py         # Inference code for Lambda
├── terraform/
│   ├── main.tf            # Includes Lambda trigger + S3 notifications
│   ├── variables.tf       # Variable definitions
│   ├── outputs.tf         # Output values
│   └── terraform.tfvars   # Variable values
├── docker/
│   ├── Dockerfile.train   # Training container
│   └── Dockerfile.lambda  # Lambda container
├── scripts/
│   ├── buildspec.yml      # CodeBuild instructions
│   └── create_trigger_lambda.py  # Creates Lambda trigger
├── data/
│   └── sample.csv         # Initial dataset
├── lambda_trigger.zip     # Lambda function for S3 events
├── requirements.txt       # Python dependencies
├── Makefile               # Command shortcuts
└── README.md

S3 Bucket Structure:
s3://mlops-bucket/
├── models/                # Trained models
│   ├── model.pkl
│   └── model.json
├── data/                  # Training data
│   └── training_data.json
└── new-data/              # Drop zone for new data
    └── *.csv              # Triggers retraining

```