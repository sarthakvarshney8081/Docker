#!/bin/bash

echo "=== Setting up Django Application with Docker ==="

# Step 0: Ensure Python and pip are installed
echo "==> Checking if Python is installed..."
if ! command -v python3 &> /dev/null
then
    echo "Python3 not found. Installing Python3..."
    sudo apt update
    sudo apt install -y python3 python3-pip
else
    echo "Python3 is already installed."
fi

# Step 1: Install Django if not already installed
echo "==> Checking if Django is installed..."
if ! python3 -m django --version &> /dev/null
then
    echo "Django not found. Installing Django..."
    pip3 install django
else
    echo "Django is already installed."
fi

# Step 2: Initialize a Django project
echo "==> Step 1: Initializing Django Project"
PROJECT_NAME="my_docker_django_app"
if [ ! -d "$PROJECT_NAME" ]; then
    django-admin startproject $PROJECT_NAME
    cd $PROJECT_NAME
else
    echo "Project directory '$PROJECT_NAME' already exists. Skipping initialization."
    cd $PROJECT_NAME
fi

# Step 3: Create a requirements.txt file
echo "==> Step 2: Creating requirements.txt file"
pip3 freeze > requirements.txt
echo "requirements.txt file created with the current dependencies."

# Step 4: Generate a Dockerfile
echo "==> Step 3: Creating Dockerfile"
cat <<EOF > Dockerfile
# Use the official Python runtime image
FROM python:3.9

# Create the app directory
WORKDIR /app

# Set environment variables
ENV PYTHONDONTWRITEBYTECODE=1
ENV PYTHONUNBUFFERED=1

# Install dependencies
COPY requirements.txt /app/
RUN pip install --no-cache-dir -r requirements.txt

# Copy project files to the container
COPY . /app/

# Expose the port
EXPOSE 8000

# Start the Django server
CMD ["python", "manage.py", "runserver", "0.0.0.0:8000"]
EOF
echo "Dockerfile created."

# Step 5: Build the Docker image
echo "==> Step 4: Building Docker Image"
docker build -t django-docker .

echo "Setup complete. Use 'docker run -p 8000:8000 django-docker' to start your container."
