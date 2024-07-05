data "aws_ami" "ubuntu" {
  most_recent = true

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-focal-20.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = ["099720109477"] 
}

resource "aws_security_group" "terraform1_sg" {
  name        = "Y_sg"
  description = "Allow SSH, HTTP, and custom port traffic"

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]  # Allow SSH from anywhere (not recommended for production)
  }

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]  # Allow HTTP from anywhere
  }

  ingress {
    from_port   = 1337
    to_port     = 1337
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]  # Allow custom port 1337 from anywhere
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]  # Allow all outbound traffic
  }
}

resource "tls_private_key" "web-server1" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "aws_key_pair" "web-server1" {
  key_name   = "ynkey"
  public_key = tls_private_key.web-server1.public_key_openssh
}

resource "aws_instance" "strapi" {
  ami                         = data.aws_ami.ubuntu.id
  instance_type               = "t2.small"  # Changed instance type to t2.small
  vpc_security_group_ids      = [aws_security_group.terraform1_sg.id]
  key_name                    = aws_key_pair.web-server1.key_name
  associate_public_ip_address = true

  user_data = <<-EOF
    #!/bin/bash
    sudo apt update
    curl -fsSL https://deb.nodesource.com/setup_20.x -o nodesource_setup.sh
    sudo bash -E nodesource_setup.sh
    sudo apt update && sudo apt install -y nodejs
    sudo npm install -g yarn pm2
    echo -e "skip\n" | npx create-strapi-app simple-strapi --quickstart
    cd simple-strapi
    echo "const strapi = require('@strapi/strapi');
    strapi().start();" > server.js
    pm2 start server.js --name strapi
    pm2 save && pm2 startup
    sleep 360
  EOF

  tags = {
    Name = "Y_strapi"
  }
}

output "instance_public_ip" {
  description = "The public IP address of the EC2 instance"
  value       = aws_instance.strapi.public_ip
}