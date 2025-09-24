#!/usr/bin/env python3
import os
import sys
import uvicorn

# Set the current directory to backend
backend_dir = r"c:\Users\asomi\OneDrive - 엘던솔루션\작업용\파이선개발\affinity-app\backend"
os.chdir(backend_dir)
sys.path.insert(0, backend_dir)

if __name__ == "__main__":
    uvicorn.run("app.main:app", host="0.0.0.0", port=8000, reload=True)