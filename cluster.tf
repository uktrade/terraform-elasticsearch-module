data "aws_vpc" "selected" {
  id = var.vpc_id
}

resource "aws_ecs_cluster" "cluster" {
  name = var.service_name
}

resource "aws_security_group" "elasticsearch-security-sg" {
  name        = "${var.service_name}-sg"
  vpc_id      = var.vpc_id

  ingress {
    protocol    = "tcp"
    from_port   = 9200
    to_port     = 9200
    cidr_blocks = [data.aws_vpc.selected.cidr_block]
  }

  ingress {
    protocol    = "tcp"
    from_port   = 9300
    to_port     = 9300
    self        = true
  }

  ingress {
    protocol    = "tcp"
    from_port   = 5601
    to_port     = 5601
    cidr_blocks = [data.aws_vpc.selected.cidr_block]
  }

  egress {
    from_port = 0
    to_port   = 0
    protocol  = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_iam_service_linked_role" "autoscaling" {
  aws_service_name = "autoscaling.amazonaws.com"
  description      = "A service linked role for autoscaling"
  custom_suffix    = var.service_name

  provisioner "local-exec" {
    command = "sleep 10"
  }
}

resource "aws_iam_role" "ec2-role" {
  name = "${var.service_name}_role"
  path = "/ecs/"

  assume_role_policy = <<EOF
{
  "Version": "2008-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": ["ec2.amazonaws.com"]
      },
      "Effect": "Allow"
    }
  ]
}
EOF
}

resource "aws_iam_instance_profile" "instance-profile" {
  name = "${var.service_name}_profile"
  role = aws_iam_role.ec2-role.name
}

resource "aws_iam_role_policy_attachment" "ecs-ec2-role" {
  role = aws_iam_role.ec2-role.id
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEC2ContainerServiceforEC2Role"
}

resource "aws_iam_role_policy_attachment" "ecs-ec2-cloudwatch-logs-role" {
  role = aws_iam_role.ec2-role.id
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchLogsFullAccess"
}

resource "aws_iam_role_policy_attachment" "ecs-ec2-cloudwatch-agent-role" {
  role = aws_iam_role.ec2-role.id
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
}

resource "aws_iam_role_policy_attachment" "ec2-s3-role" {
  role = aws_iam_role.ec2-role.id
  policy_arn = aws_iam_policy.s3-bucket-policy.arn
}

module "asg" {
  source = "terraform-aws-modules/autoscaling/aws"
  version = "~> 3.0"

  name = "${var.service_name}-ec2"

  lc_name = "${var.service_name}-lc"

  image_id                     = var.ami_version
  instance_type                = var.instance_type
  security_groups              = [aws_security_group.elasticsearch-security-sg.id]
  associate_public_ip_address  = false
  recreate_asg_when_lc_changes = false
  key_name                     = var.key_name

  root_block_device = [
    {
      volume_size           = var.volume_size
      volume_type           = "gp2"
      delete_on_termination = true
    }
  ]

  ephemeral_block_device = [
    {
      device_name           = "/dev/sdb"
      virtual_name          = "ephemeral0"
    }
  ]

  asg_name                  = "${var.service_name}-asg"
  vpc_zone_identifier       = var.subnet_ids
  health_check_type         = "EC2"
  min_size                  = 0
  max_size                  = var.instance_count
  desired_capacity          = var.instance_count
  wait_for_capacity_timeout = 0
  service_linked_role_arn   = aws_iam_service_linked_role.autoscaling.arn

  iam_instance_profile = aws_iam_instance_profile.instance-profile.id

  user_data = templatefile("${path.module}/templates/elastic-cloudinit.yml", {cluster_name = aws_ecs_cluster.cluster.name})

  tags = [
    {
      key                 = "Name"
      value               = "${var.service_name}"
      propagate_at_launch = true
    }
  ]
}
