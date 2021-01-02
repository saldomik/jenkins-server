provider aws {
    region = "eu-west-1"
}

resource "aws_vpc" "jenkins_vpc" {
  cidr_block = "10.0.0.0/16"

  tags = {
    Name = "jenkins_vpc"
  }
}


resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.jenkins_vpc.id
 }

resource "aws_route_table" "prod-route-table" {
   vpc_id = aws_vpc.jenkins_vpc.id

   route {
     cidr_block = "0.0.0.0/0"
     gateway_id = aws_internet_gateway.gw.id
   }

   route {
     ipv6_cidr_block = "::/0"
     gateway_id      = aws_internet_gateway.gw.id
   }

   tags = {
     Name = "Prod"
   }
 }

resource "aws_subnet" "main" {
  vpc_id     = aws_vpc.jenkins_vpc.id
  cidr_block = "10.0.1.0/24"

  tags = {
    Name = "Main"
  }
}

resource "aws_route_table_association" "a" {
  subnet_id      = aws_subnet.main.id
  route_table_id = aws_route_table.prod-route-table.id
}

resource "aws_security_group" "jenkins_sg" {
  name        = "jenkins_sg"
  description = "Jenkins Security Groups"
  vpc_id      = aws_vpc.jenkins_vpc.id

  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "jenkins_sg"
  }
}

resource "aws_network_interface" "web-server-nic" {
   subnet_id       = aws_subnet.main.id
   private_ips     = ["10.0.1.50"]
   security_groups = [aws_security_group.jenkins_sg.id]

 }

resource "aws_key_pair" "deployer" {
  key_name   = "deployer-key"
  public_key = file("${path.module}/id_rsa.pub")

}

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

  owners = ["099720109477"] # Canonical
}

resource "aws_instance" "jenkins-server" {
  ami           = data.aws_ami.ubuntu.id
  instance_type = "t2.micro"
  key_name = "deployer-key"
  subnet_id = aws_subnet.main.id
  vpc_security_group_ids = [aws_security_group.jenkins_sg.id]
  associate_public_ip_address = true

  provisioner "local-exec" {
    command = "echo ${self.public_ip} >> ../ansible/inventory/hosts"
  }

  tags = {
    Name = "jenkins-server"
  }
}