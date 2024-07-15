# Configure the AWS Provider
provider "aws" {
  region     = "us-east-1"
}

# Create a VPC
resource "aws_vpc" "my_vpc" {
  cidr_block = "10.0.0.0/16"
  tags = {
    Name = "my_vpc"
  }
}

# Create an Internet Gateway
resource "aws_internet_gateway" "my_igw" {
  vpc_id = aws_vpc.my_vpc.id
  tags = {
    Name = "my_igw"
  }
}

# Create a Public Subnet with a different CIDR block
resource "aws_subnet" "my_public_subnet" {
  vpc_id                 = aws_vpc.my_vpc.id
  cidr_block             = "10.0.2.0/24"
  map_public_ip_on_launch = true
  tags = {
    Name = "my_public_subnet"
  }
}

# Create a Route Table
resource "aws_route_table" "my_public_route_table" {
  vpc_id = aws_vpc.my_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.my_igw.id
  }

  tags = {
    Name = "my_public_route_table"
  }
}

# Associate the Subnet with the Route Table
resource "aws_route_table_association" "my_public_route_table_association" {
  subnet_id      = aws_subnet.my_public_subnet.id
  route_table_id = aws_route_table.my_public_route_table.id
}

# Create a Security Group that allows SSH and HTTP access
resource "aws_security_group" "ssh_access" {
  name        = "Allow SSH and HTTP"
  description = "Allow SSH and HTTP access from your IP"
  vpc_id      = aws_vpc.my_vpc.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 80
    to_port     = 80
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
    Name = "Allow SSH and HTTP"
  }
}

# Create an EC2 Instance
resource "aws_instance" "devops_instance" {
  ami                    = "ami-0b72821e2f351e396"  # Replace with your AMI ID
  instance_type          = "t2.micro"
  subnet_id              = aws_subnet.my_public_subnet.id
  vpc_security_group_ids = [aws_security_group.ssh_access.id]
  key_name               = "my_key_pair"  # Replace with your key pair name

  tags = {
    Name = "devops_instance"
  }

  provisioner "remote-exec" {
    inline = [
      "sudo yum update -y",  # For Amazon Linux, use yum instead of apt
      "sudo yum install python3-pip -y",
      "sudo pip3 install ansible",
      "ansible-playbook configure_ec2.yml"
    ]

    connection {
      type        = "ssh"
      user        = "ec2-user"
      private_key = file("my_key_pair.pem")  # Path to your private key
      host        = aws_instance.devops_instance.public_ip
    }
  }
}

# Create an Ansible Inventory File
data "template_file" "inventory" {
  template = <<-EOT
  [ec2_instances]
  ${aws_instance.devops_instance.public_ip} ansible_user=ec2-user ansible_ssh_private_key_file=/home/tk-lpt-0152/Downloads/DevOps-Infra-Automation/tffile/my_key_pair.pem
  EOT
}

resource "local_file" "inventory" {
  filename = "inventory.ini"
  content  = data.template_file.inventory.rendered
}

# Run Ansible Playbook
resource "null_resource" "run_ansible" {
  depends_on = [aws_instance.devops_instance, local_file.inventory]

  provisioner "local-exec" {
    command     = "sleep 30 && ANSIBLE_HOST_KEY_CHECKING=False ansible-playbook -i inventory.ini /home/tk-lpt-0152/Downloads/DevOps-Infra-Automation/ansible/configure_ec2.yml"
    working_dir = path.module
  }
}
