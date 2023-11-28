#!/bin/bash

# Please make sure to launch Amazon Linux 2
sudo yum update -y
sudo yum install -y httpd
sudo systemctl start httpd
sudo systemctl enable httpd
echo "Hello World from $(hostname -f)" > /var/www/html/index.html
echo "Healthy" > /var/www/html/health.html