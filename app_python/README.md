# DevOps Info Service (Python)

A small web service for the DevOps course that reports information about itself and its runtime environment.
It exposes system details, uptime, request metadata, and a simple health endpoint for monitoring/probes.

## Overview

This service provides:
- Service metadata (name/version/framework)
- System information (hostname, OS/platform, architecture, CPU count, Python version)
- Runtime info (uptime, current UTC timestamp)
- Request info (client IP, user agent, HTTP method, path)
- Health check endpoint (`/health`)

Framework: **Flask** (Python 3.11+)

## Prerequisites

- Python **3.11+**
- pip / virtualenv

## Installation

```bash
cd app_python

python -m venv venv
source venv/bin/activate

pip install -r requirements.txt
