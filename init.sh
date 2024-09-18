#!/bin/bash

# Interactive initialization script for phoenixd/lnbits stack

if [[ $1 =~ ^clear$ ]]; then
	docker compose stop
	docker compose rm
	sudo rm -Rf data/ letsencrypt/ lnbitsdata/ pgtmp/ pgdata/ docker-compose.yml default.conf
        echo "Setup cleared"
        exit 0
    fi

set -e


source $(pwd)/initlib.sh


# Check if the script is being run as root
if [ ! "$(id -u)" -eq 0 ]; then
    echo "This script needs root priviledges. Run it using sudo."
    exit 1
fi

echo "Packages update & install some dependencies..."
sudo apt update
sudo apt -y install ufw
echo 

# Check if ufw is installed
if ! command -v ufw &> /dev/null; then
    echo "ufw Firewall is not installed on this system. Please install and run again."
    exit 1
fi

# Check if ufw is active
if ! ufw status | grep -q "Status: active"; then
    echo "ufw Firewall is not active. Please enable ufw first."
    exit 1
fi

# Check if port 80 is allowed in ufw
if ufw status | grep -q "80"; then
    echo "Port $PORT is allowed through ufw."
    echo "This is OK for the certbot script"
else
    echo "Port $PORT is not allowed through ufw."
    echo "Port 80 status open is necessary to run certbot. Please open and run again"
    exit 1
fi
echo 

# Request configuration data from the user
echo ">>>Please provide needed configuration infos<<<"
echo
read -p "Enter the domain for Phoenixd API (e.g., api.yourdomain.com): " PHOENIXD_DOMAIN
read -p "Enter the domain for LNbits (e.g., lnbits.yourdomain.com): " LNBITS_DOMAIN
read -p "Do you want real Letsencrypt certificates to be issued? (y/n): " letscertificates
read -p "Do you want LNBits to use PostgreSQL? (y/n): " postgresyesno
echo

# Copy example files
cp default.conf.example default.conf
if [[ $postgresyesno =~ ^[Yy]$ ]]; then
	cp docker-compose.yml.example docker-compose.yml
	cp .env.example .env
else
	cp docker-compose.yml.sqlite.example docker-compose.yml
	cp .env.sqlite.example .env
fi

echo "docker-compose.yml and .env files set up."
echo 


# Generate certificates
if [[ ! $letscertificates =~ ^[Yy]$ ]]; then
        echo "Issuing selfsigned certificates on local host..."
	generate_certificates $PHOENIXD_DOMAIN $LNBITS_DOMAIN
else
        echo "Issuing Letsencrypt certificates on local host..."
	generate_certificates_certbot $PHOENIXD_DOMAIN $LNBITS_DOMAIN
fi

# Generate password for Postgres
POSTGRES_PASSWORD=$(generate_password)

# Update the .env file
echo "Updating the .env file..."

# Remove or comment out unnecessary variables
sed -i '/^LNBITS_BACKEND_WALLET_CLASS=/d' .env
sed -i '/^PHOENIXD_API_ENDPOINT=/d' .env
sed -i '/^PHOENIXD_API_PASSWORD=/d' .env
sed -i '/^LNBITS_DATABASE_URL=/d' .env
sed -i '/^LNBITS_SITE_TITLE=/d' .env
sed -i '/^LNBITS_SITE_TAGLINE=/d' .env
sed -i '/^LNBITS_SITE_DESCRIPTION=/d' .env

# Add or update necessary variables
update_env "LNBITS_BACKEND_WALLET_CLASS" "PhoenixdWallet"
update_env "PHOENIXD_API_ENDPOINT" "http://phoenixd:9740/"

# If no postgresql, there is no LNBITS_DATABASE_URL to configure in .env file
if [[ $postgresyesno =~ ^[Yy]$ ]]; then
	update_env "LNBITS_DATABASE_URL" "postgres://postgres:$POSTGRES_PASSWORD@postgres:5432/lnbits"
fi

update_env "LNBITS_SITE_TITLE" "$LNBITS_DOMAIN"
update_env "LNBITS_SITE_TAGLINE" "free and open-source lightning wallet"
update_env "LNBITS_SITE_DESCRIPTION" "The world's most powerful suite of bitcoin tools. Run for yourself, for others, or as part of a stack."

# Add a comment for PHOENIXD_API_PASSWORD
echo "# PHOENIXD_API_PASSWORD will be set after the first run" >> .env

echo ".env file updated successfully."

# Update the docker-compose.yml file
sed -i "s/POSTGRES_PASSWORD: XXXX/POSTGRES_PASSWORD: $POSTGRES_PASSWORD/" docker-compose.yml

# Update the default.conf file
echo "Updating the nginx default.conf file..."
sed -i "s/server_name n1\.yourdomain\.com;/server_name $PHOENIXD_DOMAIN;/" default.conf
sed -i "s/server_name lb1\.yourdomain\.com;/server_name $LNBITS_DOMAIN;/" default.conf
sed -i "s|ssl_certificate /etc/letsencrypt/live/n1\.yourdomain\.com/|ssl_certificate /etc/letsencrypt/live/$PHOENIXD_DOMAIN/|" default.conf
sed -i "s|ssl_certificate_key /etc/letsencrypt/live/n1\.yourdomain\.com/|ssl_certificate_key /etc/letsencrypt/live/$PHOENIXD_DOMAIN/|" default.conf
sed -i "s|ssl_certificate /etc/letsencrypt/live/lb1\.yourdomain\.com/|ssl_certificate /etc/letsencrypt/live/$LNBITS_DOMAIN/|" default.conf
sed -i "s|ssl_certificate_key /etc/letsencrypt/live/lb1\.yourdomain\.com/|ssl_certificate_key /etc/letsencrypt/live/$LNBITS_DOMAIN/|" default.conf

echo "Configuration completed. "
echo "Certificates have been generated for $PHOENIXD_DOMAIN and $LNBITS_DOMAIN"

# Build Docker images
echo "Building Phoenixd Docker image ..."
docker build -t massmux/phoenixd -f Dockerfile .

echo "Getting build Docker images from dockerhub"
docker pull massmux/lnbits:0.12.11
docker pull nginx
docker pull postgres

echo "Making dir data/"
mkdir data


# Start the Postgres container
if [[ $postgresyesno =~ ^[Yy]$ ]]; then
	echo "Starting the Postgres container..."
	docker compose up -d postgres

	# Wait for Postgres to be ready
	echo "Waiting for Postgres to be ready..."
	until docker compose exec postgres pg_isready
	do
	  echo "Postgres is not ready yet. Waiting..."
	  sleep 2
	done
	echo "Postgres is ready."
fi


# Start the Phoenixd container
echo "Starting the Phoenixd container..."
docker compose up -d phoenixd
wait_for_container phoenixd

echo "Waiting phoenixd to write stuffs..."
sleep 20


# Start the LNbits container
echo "Starting the LNbits container..."
docker compose up -d lnbits
wait_for_container lnbits


# Start the Nginx container
echo "Starting the Nginx container..."
docker compose up -d nginx
wait_for_container nginx


echo "All containers have been started."

# Wait a bit to allow containers to fully initialize
echo "Waiting 30 seconds to allow for complete initialization..."
sleep 30

# Stop all containers
echo "Stopping all containers..."
docker compose down

echo "All containers have been stopped."

# Configure phoenix.conf and update .env
echo "Configuring phoenix.conf and updating .env..."

# Use the relative path to the current directory
PHOENIX_CONF="$(pwd)/data/phoenix.conf"

if [ ! -f "$PHOENIX_CONF" ]; then
    echo "ERROR: phoenix.conf file not found in $PHOENIX_CONF"
    echo "Setup aborted!"
    exit 1
fi

# Allow phoenixd to listen from 0.0.0.0 
if ! grep -q "^http-bind-ip=0.0.0.0" "$PHOENIX_CONF"; then
    sed -i '1ihttp-bind-ip=0.0.0.0' "$PHOENIX_CONF"
    echo "http-bind-ip=0.0.0.0 added to phoenix.conf"
else
    echo "http-bind-ip=0.0.0.0 already present in phoenix.conf"
fi

# Extract Phoenixd password
PHOENIXD_PASSWORD=$(grep -oP '(?<=http-password=).*' "$PHOENIX_CONF")
if [ -n "$PHOENIXD_PASSWORD" ]; then
    echo "Phoenixd password found: $PHOENIXD_PASSWORD"
    update_env "PHOENIXD_API_PASSWORD" "$PHOENIXD_PASSWORD"
    echo "PHOENIXD_API_PASSWORD updated in .env file"
else
    echo "ERROR: Phoenixd password not found in phoenix.conf"
    echo "Setup aborted!"
    exit 1
fi

# Verify the contents of the .env file
echo "Relevant contents of the .env file after update:"
grep -E "^(LNBITS_BACKEND_WALLET_CLASS|PHOENIXD_API_ENDPOINT|PHOENIXD_API_PASSWORD|LNBITS_DATABASE_URL|LNBITS_SITE_TITLE|LNBITS_SITE_TAGLINE|LNBITS_SITE_DESCRIPTION)=" .env

echo "Configuration of phoenix.conf and .env update completed."

echo "Setup completed."
echo "Postgres password: $POSTGRES_PASSWORD"
if [[ $postgresyesno =~ ^[Yy]$ ]]; then
	echo "Phoenixd password: $PHOENIXD_PASSWORD"
fi

# Restart all containers
echo "Restarting all containers with the new configurations..."
docker compose up -d

echo 
echo "Initialization complete. All containers have been successfully started with the new configurations."
echo "Your system is now ready for use."
echo 
echo "- You can access LNbits at https://$LNBITS_DOMAIN"
echo "- The Phoenixd API is accessible at https://$PHOENIXD_DOMAIN"
echo "- To manage the containers, use the docker compose commands in the project directory."
echo
echo "In order to view container logs, just use 'docker compose logs [container_name]' or "
echo "docker compose logs -t -f --tail 300"
