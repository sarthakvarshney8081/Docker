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
        echo "You can install it using: sudo apt install python3-venv"
        exit 1
    fi
fi

# Check for the presence of the activation script
if [ -f "$venv_dir/bin/activate" ]; then
    source "$venv_dir/bin/activate"
    echo "Virtual environment activated."
else
    echo "Error: Virtual environment activation script not found."
    echo "Ensure you have the necessary dependencies installed and try recreating the virtual environment:"
    echo "sudo apt install python3-venv python3.12-venv -y"
    echo "Removing existing virtual environment for re-creation..."
    rm -rf "$venv_dir"
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

# Step 3.1: Generate requirements.txt
echo "==> Step 3.1: Generating requirements.txt"
pip freeze > requirements.txt
echo "requirements.txt file generated."

# Step 3.2: Create Dockerfile
echo "==> Step 3.2: Creating Dockerfile"
cat > Dockerfile <<EOL
# Use the official Python image
FROM python:3.10-slim

# Set environment variables
ENV PYTHONDONTWRITEBYTECODE 1  
ENV PYTHONUNBUFFERED 1  

# Set working directory
WORKDIR /app

#Install dependencies
RUN apt-get update && apt install -y gcc libpq-dev && pip install --upgrade pip

# Copy dependencies and install them
COPY requirements.txt /app/  
RUN pip install --no-cache-dir -r requirements.txt  

# Install Gunicorn
RUN pip install gunicorn

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

# Step 3.4: Create requirements.txt
echo "==>Step 3.4:Create requirements.txt"
cat > requirements.txt <<EOL
Django>=4.2,<5.0
psycopg2>2.9
gunicorn>=20.1
EOL
echo "requirements.txt file created."

# Step 4: Create Docker Compose File
echo "==> Step 4: Creating docker-compose.yml"
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

# Step 5: Create .env file
echo "==> Step 5: Creating .env file"
cat > .env <<EOL
DJANGO_SECRET_KEY=your_secret_key
DEBUG=True
DATABASE_ENGINE=django.db.backends.postgresql
DATABASE_NAME=dockerdjango
DATABASE_USERNAME=dbuser
DATABASE_PASSWORD=dbpassword
DATABASE_HOST=db
DATABASE_PORT=5432
EOL
echo ".env file created."

# Step 6: Update Django settings.py
echo "==> Step 6: Updating settings.py"
settings_file="$django_project_name/settings.py"
# Ensure os module is imported
sed -i "1i import os" $settings_file

# Update SECRET_KEY and DEBUG
sed -i "/^SECRET_KEY/c\SECRET_KEY = os.environ.get(\"DJANGO_SECRET_KEY\", \"fallback_secret_key\")" $settings_file
sed -i "/^DEBUG/c\DEBUG = os.environ.get(\"DEBUG\", \"True\").lower() in ['true', '1']" $settings_file

# Add DATABASES configuration if not already present
if ! grep -q "DATABASES = {" $settings_file; then
    cat >> $settings_file <<EOL

DATABASES = {
    'default': {
        'ENGINE': os.getenv('DATABASE_ENGINE', 'django.db.backends.sqlite3'),
        'NAME': os.getenv('DATABASE_NAME', 'db.sqlite3'),
        'USER': os.getenv('DATABASE_USERNAME', 'user'),
        'PASSWORD': os.getenv('DATABASE_PASSWORD', ''),
        'HOST': os.getenv('DATABASE_HOST', 'localhost'),
        'PORT': os.getenv('DATABASE_PORT', ''),
    }
}
EOL
fi

echo "Django settings updated."

# Step 7: Build and Run Docker Containers
echo "==> Step 7: Building and Running Docker Containers"
if [ ! -f .env ]; then
    echo "Error: .env file is missing. Ensure it is created before proceeding."
    exit 1
fi
docker-compose up --build -d
if [ $? -ne 0 ]; then
    echo "Error: Failed to build and run Docker containers."
    exit 1
fi
echo "Docker containers are running."

# Step 8: Run Migrations
echo "==> Step 8: Running Django Migrations"
docker-compose run web python manage.py migrate
if [ $? -ne 0 ]; then
    echo "Error: Failed to apply Django migrations."
    exit 1
fi
echo "Django migrations applied."

# Step 9: Create Superuser
echo "==> Step 9: Creating Django Superuser"
docker-compose run web python manage.py createsuperuser
if [ $? -ne 0 ]; then
    echo "Error: Failed to create Django superuser."
    exit 1
fi

echo "=== Django Application Setup Complete ==="
echo "You can access your application at http://localhost:8000."

