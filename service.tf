resource "aws_iam_role" "ecsTaskExecutionRole" {
  name               = "${var.service_name}-ecs"
  assume_role_policy = data.aws_iam_policy_document.assume_role_policy.json
}

resource "aws_iam_role_policy_attachment" "ecsTaskExecutionRole_policy" {
  role       = aws_iam_role.ecsTaskExecutionRole.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

resource "aws_iam_role" "ecsTaskRole" {
  name               = "${var.service_name}-task-ecs"
  assume_role_policy = data.aws_iam_policy_document.assume_role_policy.json
}

resource "aws_iam_policy" "ec2-discovery-policy" {
  name = "${var.service_name}_discovery"
  path = "/ecs/"

  policy = <<EOF
{
  "Statement": [
    {
      "Action": [
        "ec2:DescribeAvailabilityZones",
        "ec2:DescribeInstances",
        "ec2:DescribeRegions",
        "ec2:DescribeSecurityGroups",
        "ec2:DescribeTags"
      ],
      "Effect": "Allow",
      "Resource": [
        "*"
      ]
    }
  ],
  "Version": "2012-10-17"
}
EOF
}

resource "aws_iam_role_policy_attachment" "ec2-discovery-role-attachment" {
  role = aws_iam_role.ecsTaskRole.id
  policy_arn = aws_iam_policy.ec2-discovery-policy.arn
}

resource "aws_cloudwatch_log_group" "logs" {
  name = "/ecs/${var.service_name}"
}

data "aws_iam_policy_document" "assume_role_policy" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
  }
}

resource "aws_ecs_task_definition" "task" {
  family = "${var.service_name}-task"
  execution_role_arn = aws_iam_role.ecsTaskExecutionRole.arn
  task_role_arn = aws_iam_role.ecsTaskRole.arn
  network_mode = "bridge"

  volume {
    name      = "data"
    host_path = "/var/elasticsearch/data"
  }

  container_definitions = templatefile("${path.module}/tasks/elastic-task.json",
  {
    cluster_name = var.service_name
    system_key = var.elastic_config["system_key"]
    image = var.image
    cpu = var.task_cpu
    memory = var.task_memory
    es_ssl_key = var.elastic_config["ssl_key"]
    es_ssl_cert = var.elastic_config["ssl_cert"]
    es_ssl_ca = var.elastic_config["ssl_ca"]
    saml_cert = var.elastic_config["saml_cert"]
    saml_key = var.elastic_config["saml_key"]
    cluster_security_group = aws_security_group.elasticsearch-security-sg.id
    elastic_password = var.elastic_config["password"]
    log_group = aws_cloudwatch_log_group.logs.name
    region = "eu-west-2"
    stream_prefix = "elasticsearch"
  })
}

resource "aws_ecs_service" "service" {
  name            = var.service_name
  cluster         = aws_ecs_cluster.cluster.id
  task_definition = aws_ecs_task_definition.task.arn
  desired_count   = var.task_count
  launch_type     = "EC2"

  load_balancer {
    target_group_arn = aws_lb_target_group.main.arn
    container_name   = "elasticsearch"
    container_port   = 9200
  }
}
