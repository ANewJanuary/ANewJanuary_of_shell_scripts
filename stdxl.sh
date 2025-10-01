#!/bin/sh
cd ~/stable-diffusion-webui
# Optional: "git pull" to update the repository
source venv/bin/activate

# It's possible that you don't need "--precision full", dropping "--no-half" however crashes my drivers
python launch.py --no-half --skip-torch-cuda-test

