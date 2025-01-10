# Django Deployment Script with Docker  
This repository contains a shell script to automate the deployment of a Django project with Docker.  

## Features  
- Automates the creation of a `docker-compose.yml` file for Django and PostgreSQL.  
- Automatically configures environment variables for secure and seamless integration.  
- Updates `settings.py` for compatibility with environment variables and PostgreSQL.  
- Builds and runs Docker containers for Django and PostgreSQL.  
- Automates migrations and the creation of a Django superuser.  

## How to Use  
1. Clone the repository.  
2. Customize the `.env` file with your project-specific values.  
3. Run the script using `setup_docker_django.sh`.  
4. Access your Django application at `http://localhost:8000`.  

## Prerequisites  
- Docker and Docker Compose installed.  
- A Django project ready for deployment.  

## License  
This project is licensed under the MIT License.  
