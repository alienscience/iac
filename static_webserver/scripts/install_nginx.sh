#!/usr/bin/env bash

export DEBIAN_FRONTEND=noninteractive

# Install nginx
sudo -E apt-get -y install nginx

# Allow ubuntu user to upload HTML files
sudo chown -R ubuntu /var/www/html
