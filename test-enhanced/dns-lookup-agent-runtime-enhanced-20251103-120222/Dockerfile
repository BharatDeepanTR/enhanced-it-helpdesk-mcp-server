# Fixed Dockerfile for AWS Bedrock Agent Core Runtime
# Includes proper Lambda Runtime Interface Client (RIC)

FROM public.ecr.aws/lambda/python:3.11

# Set working directory
WORKDIR ${LAMBDA_TASK_ROOT}

# Copy requirements and install dependencies
COPY requirements.txt .
RUN pip install --no-cache-dir --upgrade pip && \
    pip install --no-cache-dir -r requirements.txt

# Copy application code
COPY chatops_route_dns_intent.py .
COPY chatops_helpers.py .
COPY chatops_config.py .
COPY lambda_handler.py .

# Optional: Copy container handler for debugging
COPY container_handler.py .

# Set the Lambda handler
CMD ["lambda_handler.lambda_handler"]