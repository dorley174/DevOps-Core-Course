# Production-oriented image for a small Flask app.
# Pin a specific Python version for reproducible builds.
FROM python:3.13.1-slim

# Python runtime defaults: no .pyc files, unbuffered logs (better for containers)
ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1

WORKDIR /app

# Create a dedicated non-root user with numeric UID/GID.
RUN addgroup --system --gid 10001 app \
    && adduser --system --uid 10001 --ingroup app --no-create-home app \
    && mkdir -p /data /config \
    && chown -R 10001:10001 /app /data /config

# Install dependencies first to leverage Docker layer caching.
COPY requirements.txt ./
RUN pip install --no-cache-dir -r requirements.txt

# Copy only the application code needed at runtime.
COPY app.py ./

# Drop privileges using a numeric user for Kubernetes runAsNonRoot validation.
USER 10001:10001

# Document the port (Flask defaults to 5000 in this repo)
EXPOSE 5000

# Start the application
CMD ["python", "app.py"]
