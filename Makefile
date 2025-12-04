# ---------------------------------------------------- #
# Makefile: Command Shortcuts
# ---------------------------------------------------- #

.PHONY: help setup test-local deploy test-api destroy clean

help:
	@echo "Available commands:"
	@echo "  make setup        - Initialize Terraform"
	@echo "  make test-local   - Test training locally"
	@echo "  make deploy       - Deploy infrastructure"
	@echo "  make test-api     - Test deployed API"
	@echo "  make destroy      - Tear down all resources"
	@echo "  make clean        - Clean local files"

setup:
	cd terraform && terraform init

test-local:
	python src/train.py
	docker build -t test-train -f docker/Dockerfile.train .
	docker run test-train

deploy:
	cd terraform && terraform apply -auto-approve

test-api:
	@echo "Testing API..."
	@API_URL=$$(cd terraform && terraform output -raw lambda_function_url); \
	curl -X POST $$API_URL \
		-H "Content-Type: application/json" \
		-d '{"x": 5}' | python -m json.tool

destroy:
	cd terraform && terraform destroy -auto-approve

clean:
	rm -rf terraform/.terraform terraform/*.tfstate*
	rm -f models/*.pkl models/*.json