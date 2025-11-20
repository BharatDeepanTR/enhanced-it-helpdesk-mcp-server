# Multi-stage secure Dockerfile for ARM64 architecture
# Base image with latest available Python 3.11 slim
FROM --platform=linux/arm64 python:3.11-slim-bookworm as builder

# Create non-root user for security
RUN groupadd --gid 10001 appgroup && \
    useradd --uid 10001 --gid appgroup --shell /bin/bash --create-home appuser

# Install only necessary build dependencies
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        gcc \
        python3-dev \
        && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

# Create application directory
WORKDIR /app

# Copy requirements first for better caching
COPY requirements.txt requirements-security.txt ./

# Create virtual environment and install dependencies
RUN python -m venv /opt/venv && \
    /opt/venv/bin/pip install --no-cache-dir --upgrade pip==23.3.1 && \
    /opt/venv/bin/pip install --no-cache-dir --requirement requirements.txt && \
    /opt/venv/bin/pip install --no-cache-dir --requirement requirements-security.txt

# Production stage - minimal runtime image
FROM --platform=linux/arm64 python:3.11-slim-bookworm as production

# Security hardening - create non-root user
RUN groupadd --gid 10001 appgroup && \
    useradd --uid 10001 --gid appgroup --shell /bin/bash --create-home appuser

# Install only runtime dependencies and security updates
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        ca-certificates \
        curl \
        && \
    apt-get upgrade -y && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/* && \
    # Remove unnecessary packages and files
    apt-get autoremove -y && \
    # Security: Remove shell history and package cache
    rm -rf /root/.cache /home/appuser/.cache

# Copy virtual environment from builder stage
COPY --from=builder --chown=appuser:appgroup /opt/venv /opt/venv

# Set up application directory
WORKDIR /app
RUN chown appuser:appgroup /app

# Copy application files with proper ownership
COPY --chown=appuser:appgroup chatops_route_dns_intent.py ./
COPY --chown=appuser:appgroup chatops_helpers.py ./
COPY --chown=appuser:appgroup chatops_config.py ./
COPY --chown=appuser:appgroup container_handler.py ./

# Create directory for GenAI configuration
RUN mkdir -p /opt && chown appuser:appgroup /opt

# Copy GenAI config file if it exists
COPY --chown=appuser:appgroup function.txt /opt/function.txt 2>/dev/null || echo '{"url":"","headers":{}}' > /opt/function.txt && chown appuser:appgroup /opt/function.txt

# Switch to non-root user
USER appuser

# Set secure environment variables
ENV PATH="/opt/venv/bin:$PATH" \
    PYTHONPATH="/app" \
    PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1 \
    PIP_NO_CACHE_DIR=1 \
    PIP_DISABLE_PIP_VERSION_CHECK=1 \
    # Security environment variables
    PYTHONASYNCIODEBUG=0 \
    PYTHONHASHSEED=random \
    # Application environment
    ENV=production \
    APP_CONFIG_PATH=/config

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD python -c "import chatops_route_dns_intent; print('Health check passed')" || exit 1

# Security: Use specific port and run as non-root
EXPOSE 8080

# Set proper file permissions
RUN chmod 444 /app/*.py && \
    chmod 644 /opt/function.txt

# Use exec form for better signal handling
ENTRYPOINT ["python", "container_handler.py"]

# Metadata
LABEL maintainer="DevOps Team" \
      version="1.0.0" \
      description="DNS Lookup Service - ARM64 Secure Container" \
      architecture="arm64" \
      security.scan-date="" \
      org.opencontainers.image.title="DNS Lookup Service" \
      org.opencontainers.image.description="Secure DNS lookup service without Lex dependencies" \
      org.opencontainers.image.version="1.0.0" \
      org.opencontainers.image.architecture="arm64"