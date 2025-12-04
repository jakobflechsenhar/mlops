# ---------------------------------------------------- #
# README: MLOps Project
# ---------------------------------------------------- #

```
MLOps/
├── src/
│   ├── train.py          # Trains tiny model
│   ├── predict.py        # Inference code for Lambda
│   └── utils.py          # Helper functions
├── terraform/
│   ├── main.tf           # Main Terraform config
│   ├── variables.tf      # Variable definitions
│   ├── outputs.tf        # Output values
│   └── terraform.tfvars  # Variable values
├── docker/
│   ├── Dockerfile.train  # Training container
│   └── Dockerfile.lambda # Lambda container
├── scripts/
│   ├── buildspec.yml     # CodeBuild instructions
│   ├── deploy.sh         # Deployment helper
│   └── cleanup.sh        # Cleanup script
├── tests/
│   └── test_model.py     # Basic tests
├── data/
│   └── sample.csv        # Tiny dataset
├── requirements.txt      # Python dependencies
├── Makefile              # ???? Command shortcuts ????
└── README.md             # Documentation
```