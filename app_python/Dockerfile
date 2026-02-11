# syntax=docker/dockerfile:1

# Production-oriented image for a small Flask app.
# Pin a specific Python version for reproducible builds.
FROM python:3.13.1-slim

# Python runtime defaults: no .pyc files, unbuffered logs (better for containers)
ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1

WORKDIR /app

# Create a dedicated non-root user (mandatory best practice).
RUN addgroup --system app \
    && adduser --system --ingroup app --no-create-home app

# Install dependencies first to leverage Docker layer caching.
COPY requirements.txt ./
RUN pip install --no-cache-dir -r requirements.txt

# Copy only the application code needed at runtime.
COPY app.py ./

# Drop privileges
USER app

# Document the port (Flask defaults to 5000 in this repo)
EXPOSE 5000

# Start the application
CMD ["python", "app.py"]
