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

if ! command -v django-admin &> /dev/null; then
    echo "Django is not installed. Installing Django..."
    pip install django
    if ! command -v django-admin &> /dev/null; then
        echo "Error: django-admin command is still not found. Ensure Django is installed and PATH is correctly set."
        exit 1
    fi
fi

if ! command -v docker &> /dev/null; then
    echo "Error: Docker is not installed. Please install Docker and try again."
    exit 1
fi

if ! command -v docker-compose &> /dev/null; then
    echo "Error: Docker Compose is not installed. Please install Docker Compose and try again."
    exit 1
fi

# Step 1: Initialize Django Project
echo "==> Step 1: Initializing Django Project"
django_project_name="my_docker_django_app"

if [ ! -d "$django_project_name" ]; then
    django-admin startproject $django_project_name
    cd $django_project_name
    echo "Django project $django_project_name created."
else
    cd $django_project_name
    echo "Django project $django_project_name already exists. Skipping creation."
fi

# Step 2: Generate requirements.txt and handle specific dependency issues
echo "==> Step 2: Generating requirements.txt"
pip freeze > requirements.txt
if grep -q "bcc==0.29.1" requirements.txt; then
    echo "Removing problematic dependency: bcc==0.29.1"
    sed -i '/bcc==0.29.1/d' requirements.txt
fi
if ! grep -q Django requirements.txt; then
    echo "Django==$(django-admin --version)" >> requirements.txt
fi
echo "requirements.txt file generated."

# Step 3: Create Dockerfile
echo "==> Step 3: Creating Dockerfile"
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

# Step 5: Check for externally-managed environment error
echo "==> Step 5: Checking for externally-managed-environment"
if python3 -m ensurepip &> /dev/null; then
    echo "System-managed environment detected. Consider using a virtual environment for better dependency management."
fi

# Step 6: Update Django settings.py
echo "==> Step 6: Updating settings.py"
settings_file="$django_project_name/settings.py"
sed -i "/^SECRET_KEY/c\SECRET_KEY = os.environ.get(\"DJANGO_SECRET_KEY\", \"fallback_secret_key\")" $settings_file
sed -i "/^DEBUG/c\DEBUG = os.environ.get(\"DEBUG\", \"True\").lower() in ['true', '1']" $settings_file

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
echo "Django settings updated."

# Step 7: Build and Run Docker Containers
echo "==> Step 7: Building and Running Docker Containers"
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
