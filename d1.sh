#!/bin/bash

# Exit immediately if a command exits with a non-zero status
set -e

echo "=== Setting up Django Application with Docker ==="

# Step 0: Check for required commands
echo "==> Step 0: Checking for dependencies"
if ! command -v python3 &> /dev/null; then
    echo "Error: Python3 is not installed. Please install Python3 and try again."
    exit 1
fi

if ! command -v pip &> /dev/null; then
    echo "Error: pip is not installed. Please install pip and try again."
    exit 1
fi

if ! command -v docker &> /dev/null; then
    echo "Error: Docker is not installed. Please install Docker and try again."
    exit 1
fi

if ! command -v docker-compose &> /dev/null; then
    echo "Error: Docker Compose is not installed. Please install Docker Compose and try again."
    exit 1
fi

# Step 1: Create and activate a virtual environment
echo "==> Step 1: Setting up a virtual environment"
venv_dir=".venv"
if [ ! -d "$venv_dir" ]; then
    echo "Creating a virtual environment in $venv_dir..."
    python3 -m venv "$venv_dir"
    if [ $? -ne 0 ]; then
        echo "Error: Failed to create the virtual environment. Ensure that the 'python3-venv' package is installed on your system."
        exit 1
    fi
fi

if [ -f "$venv_dir/bin/activate" ]; then
    source "$venv_dir/bin/activate"
    echo "Virtual environment activated."
else
    echo "Error: Virtual environment activation script not found. Please check if the virtual environment was created properly."
    echo "Diagnostics: Listing contents of $venv_dir"
    ls -R "$venv_dir"
    exit 1
fi

# Step 2: Install Django in the virtual environment
echo "==> Step 2: Installing Django in the virtual environment"
pip install --upgrade pip setuptools wheel
pip install django
if ! command -v django-admin &> /dev/null; then
    echo "Error: Django installation failed."
    deactivate
    exit 1
fi
echo "Django installed successfully in the virtual environment."

# Step 3: Initialize Django Project
echo "==> Step 3: Initializing Django Project"
django_project_name="my_docker_django_app"

if [ ! -d "$django_project_name" ]; then
    django-admin startproject $django_project_name
    cd $django_project_name
    echo "Django project $django_project_name created."
else
    cd $django_project_name
    echo "Django project $django_project_name already exists. Skipping creation."
fi

# Step 4: Generate requirements.txt
echo "==> Step 4: Generating requirements.txt"
pip freeze > requirements.txt
if grep -q "bcc==0.29.1" requirements.txt; then
    echo "Removing problematic dependency: bcc==0.29.1"
    sed -i '/bcc==0.29.1/d' requirements.txt
fi
echo "requirements.txt file generated."

# Step 5: Create Dockerfile
echo "==> Step 5: Creating Dockerfile"
cat > Dockerfile <<EOL
# Use the official Python image
FROM python:3.9-slim

# Set environment variables
ENV PYTHONDONTWRITEBYTECODE 1  
ENV PYTHONUNBUFFERED 1  

# Set working directory
WORKDIR /app

# Copy dependencies and install them
COPY requirements.txt /app/  
RUN pip install --no-cache-dir -r requirements.txt  

# Copy project files to the container
COPY . /app

# Add a non-root user for better security
RUN useradd -m -r appuser && chown -R appuser /app  
USER appuser  

# Expose the application port and define the startup command
EXPOSE 8000  
CMD ["gunicorn", "--bind", "0.0.0.0:8000", "--workers", "3", "$django_project_name.wsgi:application"]
EOL
echo "Dockerfile created."

# Step 6: Create Docker Compose File
echo "==> Step 6: Creating docker-compose.yml"
cat > docker-compose.yml <<EOL
version: "3.8"

services:
  db:
    image: postgres:14
    environment:
      POSTGRES_DB: \${DATABASE_NAME}
      POSTGRES_USER: \${DATABASE_USERNAME}
      POSTGRES_PASSWORD: \${DATABASE_PASSWORD}
    ports:
      - "5432:5432"
    volumes:
      - postgres_data:/var/lib/postgresql/data
    env_file:
      - .env

  web:
    build:
      context: .
    container_name: django-docker
    ports:
      - "8000:8000"
    depends_on:
      - db
    environment:
      DJANGO_SECRET_KEY: \${DJANGO_SECRET_KEY}
      DEBUG: \${DEBUG}
      DATABASE_ENGINE: \${DATABASE_ENGINE}
      DATABASE_NAME: \${DATABASE_NAME}
      DATABASE_USERNAME: \${DATABASE_USERNAME}
      DATABASE_PASSWORD: \${DATABASE_PASSWORD}
      DATABASE_HOST: db
      DATABASE_PORT: \${DATABASE_PORT}
    env_file:
      - .env

volumes:
  postgres_data:
EOL
echo "docker-compose.yml file created."

# Step 7: Run Django Application Setup
echo "==> Step 7: Running Django Application Setup"
docker-compose up --build -d

echo "=== Django Application Setup Complete ==="
echo "You can access your application at http://localhost:8000."

# Deactivate the virtual environment
deactivate
