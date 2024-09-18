#!/bin/bash

# Update or add a variable in the .env file
#

# Function to generate a random password
generate_password() {
    openssl rand -base64 12 | tr -d "=+/" | cut -c1-16
}

update_env() {
    local key=$1
    local value=$2
    local file=".env"
    if grep -q "^$key=" "$file"; then
        sed -i "s|^$key=.*|$key=$value|" "$file"
    else
        echo "$key=$value" >> "$file"
    fi
}

# Wait for a container to be ready
wait_for_container() {
    echo "Waiting for $1 to be ready..."
    until [ "`docker inspect --format=\"{{.State.Running}}\" $1`"=="true" ]; do
        sleep 1;
    done;
    sleep 2;
    echo "$1 is ready."
}

# Generate self-signed certificates
generate_certificates() {
    local phoenixd_domain=$1
    local lnbits_domain=$2
    local cert_dir="letsencrypt/live"

    echo "Generating self-signed certificates for testing..."

    # Create necessary directories
    mkdir -p "$cert_dir/$phoenixd_domain"
    mkdir -p "$cert_dir/$lnbits_domain"

    # Generate certificates for Phoenixd domain
    openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
        -keyout "$cert_dir/$phoenixd_domain/privkey.pem" \
        -out "$cert_dir/$phoenixd_domain/fullchain.pem" \
        -subj "/CN=$phoenixd_domain" 2>/dev/null

    if [ $? -eq 0 ]; then
        echo "Certificates for $phoenixd_domain generated successfully."
    else
        echo "An error occurred while generating certificates for $phoenixd_domain."
        exit 1
    fi

    # Generate certificates for LNbits domain
    openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
        -keyout "$cert_dir/$lnbits_domain/privkey.pem" \
        -out "$cert_dir/$lnbits_domain/fullchain.pem" \
        -subj "/CN=$lnbits_domain" 2>/dev/null

    if [ $? -eq 0 ]; then
        echo "Certificates for $lnbits_domain generated successfully."
    else
        echo "An error occurred while generating certificates for $lnbits_domain."
        exit 1
    fi

    echo "Self-signed certificates generated successfully for testing."
}

# Generate Letsencrypt certificates
generate_certificates_certbot() {
    local phoenixd_domain=$1
    local lnbits_domain=$2

    echo "Generating valid certificates using Certbot..."
    echo "Port 80 must be open on the host server..."

    # Check if Certbot is installed
    if ! command -v certbot &> /dev/null; then
        echo "Certbot is not installed. Please install Certbot and try again."
        exit 1
    fi

    # Prompt for email address
    read -p "Enter an email address for important account notifications: " cert_email

    # Prompt for Terms of Service agreement
    echo "Please read the Let's Encrypt Terms of Service at https://letsencrypt.org/documents/LE-SA-v1.2-November-15-2017.pdf"
    read -p "Do you agree to the Let's Encrypt Terms of Service? (y/n): " tos_agreement
    if [[ ! $tos_agreement =~ ^[Yy]$ ]]; then
        echo "You must agree to the Terms of Service to continue."
        exit 1
    fi

    # Generate certificate for Phoenixd domain
    echo "Generating certificate for $phoenixd_domain"
    sudo certbot certonly --standalone -d $phoenixd_domain --email $cert_email --agree-tos

    if [ $? -eq 0 ]; then
        echo "Certificate for $phoenixd_domain generated successfully."
    else
        echo "An error occurred while generating certificate for $phoenixd_domain."
        exit 1
    fi

    # Generate certificate for LNbits domain
    echo "Generating certificate for $lnbits_domain"
    sudo certbot certonly --standalone -d $lnbits_domain --email $cert_email --agree-tos

    if [ $? -eq 0 ]; then
        echo "Certificate for $lnbits_domain generated successfully."
    else
        echo "An error occurred while generating certificate for $lnbits_domain."
        exit 1
    fi

    echo "Valid certificates generated successfully using Certbot."
    echo "Copying letsencrypt dir..."
    sudo cp -R /etc/letsencrypt .
}

## Functions section end.

