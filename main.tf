# Configure the AWS Provider
provider "aws" {
  region = "eu-central-1"
  #access_key = ""
  #secret:key = ""
}


#Create vpc
resource "aws_vpc" "web_vpc" {
  cidr_block       = "10.0.0.0/16"
  instance_tenancy = "default"

  tags = {
    Name = "web_vpc"
  }
}


#Create internet GTW
resource "aws_internet_gateway" "web_gw" {
  vpc_id = aws_vpc.web_vpc.id

  tags = {
    Name = "web_gw"
  }
}

#Create internet Route Table
resource "aws_route_table" "web_rt" {
  vpc_id = aws_vpc.web_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.web_gw.id
  }

  route {
    ipv6_cidr_block        = "::/0"
    gateway_id = aws_internet_gateway.web_gw.id
  }

  tags = {
    Name = "web_rt"
  }
}

#Create subnets 
resource "aws_subnet" "web_subnet_1" {
  vpc_id     = aws_vpc.web_vpc.id
  cidr_block = "10.0.1.0/24"

  tags = {
    Name = "web_subnet_1"
  }
}


#Create Route table association
resource "aws_route_table_association" "web_rt_1" {
  subnet_id      = aws_subnet.web_subnet_1.id
  route_table_id = aws_route_table.web_rt.id
}


#Create SG
resource "aws_security_group" "web_sg" {
  name        = "web_sg"
  description = "Allow TLS inbound traffic"
  vpc_id      = aws_vpc.web_vpc.id

  ingress {
    description      = "HTTPS from ALL"
    from_port        = 443
    to_port          = 443
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  ingress {
    description      = "HTPP from ALL"
    from_port        = 80
    to_port          = 80
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  ingress {
    description      = "SSH from VPC"
    from_port        = 22
    to_port          = 22
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  tags = {
    Name = "web_sg"
  }
}

# Create a network interface nic
resource "aws_network_interface" "web_nic" {
  subnet_id       = aws_subnet.web_subnet_1.id
  private_ips     = ["10.0.1.50"]
  security_groups = [aws_security_group.web_sg.id]
}


#Create eip
resource "aws_eip" "web-eip" {
  vpc                       = true
  network_interface         = aws_network_interface.web_nic.id
  associate_with_private_ip = "10.0.1.50"
  depends_on = [aws_internet_gateway.web_gw]

}

# Create EC2 instance
resource "aws_instance" "web_server_1" {
  ami           = "ami-0a49b025fffbbdac6"
  instance_type = "t2.micro"
  key_name = "my-key-pair-eu-centra-1"


  network_interface {
    network_interface_id = aws_network_interface.web_nic.id
    device_index         = 0
  }
  
  user_data = <<-EOF
              #!/bin/bash
              sudo apt update -y 
              sudo apt install apache2 -y
              sudo systemctl start apache2
              sudo bash -c 'echo my first web server > var/www/html/index.html'
              EOF

  tags = {
    Name = "web_server_1"
  }

}

output "server_public_ip" {
    value = aws_eip.web-eip.public_ip
}


output "server_private_ip" {
    value = aws_instance.web_server_1.private_ip
}
