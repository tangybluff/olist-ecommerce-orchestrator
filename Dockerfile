# =============================================================================
# Dockerfile
#
# Purpose:
#   Builds a single Python 3.12 image containing the ingestion pipeline,
#   dbt, and the Dagster webserver/daemon.  All three services in
#   docker-compose.yml use this same image with different CMD overrides.
#
# Why we need it:
#   Containerising the project eliminates "works on my machine" issues.
#   The image can be pushed to Artifact Registry and run on Cloud Run or
#   GKE without any additional setup.
#
# Reproducibility – change if needed:
#   python:3.12-slim  -> update the base image tag when upgrading Python
#   build-essential / git -> needed to compile some Python C-extensions
#                           and for dbt to resolve git-based packages
# =============================================================================

FROM python:3.12-slim

# Prevent .pyc files and enable real-time log output in Docker logs
ENV PYTHONDONTWRITEBYTECODE=1
ENV PYTHONUNBUFFERED=1

WORKDIR /app

# Install OS-level build dependencies.
# build-essential: required by some Python packages that compile C extensions.
# git: required by dbt to resolve packages from git sources.
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    git \
    && rm -rf /var/lib/apt/lists/*

# Install Python dependencies first (separate layer = faster rebuilds when
# only application code changes).
COPY requirements.txt ./
RUN pip install --upgrade pip && pip install -r requirements.txt

# Copy the entire project into the image.
COPY . .

# Default command runs one ingestion execution.
# Overridden in docker-compose.yml for the dagster-webserver and dagster-daemon services.
CMD ["python", "-m", "ingestion.pipeline.run"]
