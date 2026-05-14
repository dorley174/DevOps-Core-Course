# Lab 18 Nix App

This directory contains a copy of the Lab 1/2 Python DevOps Info Service and the Nix expressions required by Lab 18.

Files:

- `app.py` — Flask service copied from `app_python/`.
- `requirements.txt` — original pip dependency file for comparison.
- `Dockerfile` — original Lab 2 Dockerfile for comparison.
- `default.nix` — reproducible Nix build for the Python app.
- `docker.nix` — reproducible Docker image built with Nix `dockerTools`.

Bonus flakes are intentionally not included.
