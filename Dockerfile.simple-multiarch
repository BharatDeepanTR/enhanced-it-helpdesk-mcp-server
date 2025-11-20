# Simplified Dockerfile for Agent Core Runtime (Multi-arch compatible)
# Avoids complex operations that fail in QEMU emulation

FROM python:3.11-slim-bookworm

# Create non-root user for security
RUN groupadd --gid 10001 appgroup && \
    useradd --uid 10001 --gid appgroup --shell /bin/bash --create-home appuser

# Set working directory
WORKDIR /app

# Copy requirements and install Python packages first (better caching)
COPY requirements.txt .
RUN pip install --no-cache-dir --upgrade pip && \
    pip install --no-cache-dir -r requirements.txt

# Copy application files
COPY chatops_route_dns_intent.py .
COPY chatops_helpers.py .
COPY chatops_config.py .
COPY container_handler.py .
COPY lambda_handler.py .

# Security hardening - minimal operations
RUN chown -R appuser:appgroup /app && \
    chmod -R 755 /app

# Switch to non-root user
USER appuser

# Expose port for compatibility
EXPOSE 8080

# Lambda handler entry point for Agent Core Runtime
CMD ["lambda_handler.lambda_handler"]