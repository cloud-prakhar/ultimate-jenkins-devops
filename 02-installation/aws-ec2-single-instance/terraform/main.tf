data "aws_ssm_parameter" "ubuntu_2404_ami" {
  name = "/aws/service/canonical/ubuntu/server/24.04/stable/current/amd64/hvm/ebs-gp3/ami-id"
}

locals {
  vpc_id    = var.create_vpc ? aws_vpc.this[0].id : var.existing_vpc_id
  subnet_id = var.create_vpc ? aws_subnet.this[0].id : var.existing_subnet_id
  common_tags = {
    Project = "ultimate-jenkins-devops"
    Module  = "aws-ec2-single-instance"
  }
}

resource "aws_vpc" "this" {
  count                = var.create_vpc ? 1 : 0
  cidr_block           = "10.42.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = merge(local.common_tags, {
    Name = "${var.name_prefix}-vpc"
  })
}

resource "aws_internet_gateway" "this" {
  count  = var.create_vpc ? 1 : 0
  vpc_id = aws_vpc.this[0].id

  tags = merge(local.common_tags, {
    Name = "${var.name_prefix}-igw"
  })
}

resource "aws_subnet" "this" {
  count                   = var.create_vpc ? 1 : 0
  vpc_id                  = aws_vpc.this[0].id
  cidr_block              = "10.42.1.0/24"
  map_public_ip_on_launch = true

  tags = merge(local.common_tags, {
    Name = "${var.name_prefix}-subnet"
  })
}

resource "aws_route_table" "public" {
  count  = var.create_vpc ? 1 : 0
  vpc_id = aws_vpc.this[0].id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.this[0].id
  }

  tags = merge(local.common_tags, {
    Name = "${var.name_prefix}-rt"
  })
}

resource "aws_route_table_association" "public" {
  count          = var.create_vpc ? 1 : 0
  subnet_id      = aws_subnet.this[0].id
  route_table_id = aws_route_table.public[0].id
}

resource "aws_security_group" "jenkins" {
  name        = "${var.name_prefix}-sg"
  description = "Jenkins lab security group"
  vpc_id      = local.vpc_id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  dynamic "ingress" {
    for_each = var.allowed_cidr_for_jenkins == null ? [] : [var.allowed_cidr_for_jenkins]
    content {
      description = "Optional less-secure Jenkins web access"
      from_port   = 8080
      to_port     = 8080
      protocol    = "tcp"
      cidr_blocks = [ingress.value]
    }
  }

  tags = merge(local.common_tags, {
    Name = "${var.name_prefix}-sg"
  })
}

data "aws_iam_policy_document" "assume_role" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "jenkins" {
  name               = "${var.name_prefix}-role"
  assume_role_policy = data.aws_iam_policy_document.assume_role.json
}

resource "aws_iam_role_policy_attachment" "ssm" {
  role       = aws_iam_role.jenkins.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_role_policy_attachment" "cloudwatch" {
  role       = aws_iam_role.jenkins.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
}

resource "aws_iam_role_policy" "optional_ecr_readme" {
  name = "${var.name_prefix}-optional-ecr"
  role = aws_iam_role.jenkins.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["ecr:GetAuthorizationToken"]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "ecr:BatchGetImage",
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchCheckLayerAvailability"
        ]
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_instance_profile" "jenkins" {
  name = "${var.name_prefix}-profile"
  role = aws_iam_role.jenkins.name
}

resource "aws_instance" "jenkins" {
  ami                         = data.aws_ssm_parameter.ubuntu_2404_ami.value
  instance_type               = var.instance_type
  subnet_id                   = local.subnet_id
  vpc_security_group_ids      = [aws_security_group.jenkins.id]
  iam_instance_profile        = aws_iam_instance_profile.jenkins.name
  associate_public_ip_address = true
  user_data                   = file("${path.module}/user-data.sh")

  root_block_device {
    volume_size           = var.root_volume_size
    volume_type           = "gp3"
    delete_on_termination = true
  }

  tags = merge(local.common_tags, {
    Name = "${var.name_prefix}-instance"
  })
}
