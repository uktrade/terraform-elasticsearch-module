resource "aws_ecs_task_definition" "kibana-task" {
  family = "${var.kibana_service_name}-task"
  execution_role_arn = aws_iam_role.ecsTaskExecutionRole.arn
  task_role_arn = aws_iam_role.ecsTaskRole.arn
  network_mode = "bridge"

  container_definitions = templatefile("${path.module}/tasks/kibana-task.json",
  {
    image = var.kibana_image
    cpu = var.kibana_cpu
    memory = var.kibana_memory
    ssl_cert = var.kibana_config["ssl_cert"]
    ssl_key = var.kibana_config["ssl_key"]
    elastic_url = "https://elastic.elk.local:9200"
    elastic_username = var.kibana_config["username"]
    elastic_password = var.kibana_config["password"]
    encryption_key = var.kibana_config["encryption_key"]
    verification_mode = var.kibana_config["verification_mode"]

    log_group = aws_cloudwatch_log_group.logs.name
    region = "eu-west-2"
    stream_prefix = "kibana"
  })
}

resource "aws_ecs_service" "kibana-service" {
  name            = var.kibana_service_name
  cluster         = aws_ecs_cluster.cluster.id
  task_definition = aws_ecs_task_definition.kibana-task.arn
  desired_count   = var.kibana_task_count
  launch_type     = "EC2"

  load_balancer {
    target_group_arn = aws_lb_target_group.kibana-tg.arn
    container_name   = "kibana"
    container_port   = 5601
  }
}

resource "aws_security_group" "kibana-alb-sg" {
  name = "${var.kibana_service_name}-alb-sg"

  vpc_id = var.vpc_id

  ingress {
    from_port = 443
    to_port = 443
    protocol = "tcp"
    cidr_blocks = [
      var.kibana_peered_vpc_cidr,
      data.aws_vpc.selected.cidr_block
    ]
  }

  ingress {
    from_port = 80
    to_port = 80
    protocol = "tcp"
    cidr_blocks = [
      var.kibana_peered_vpc_cidr,
      data.aws_vpc.selected.cidr_block
    ]
  }

  egress {
    from_port = 0
    to_port = 0
    protocol = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_lb" "kibana-lb" {
  name               = "${var.kibana_service_name}-lb"
  internal           = true
  load_balancer_type = "application"
  security_groups    = [aws_security_group.kibana-alb-sg.id]
  subnets            = var.subnet_ids
}

resource "aws_lb_target_group" "kibana-tg" {
  name     = "${var.kibana_service_name}-tg"
  port     = 5601
  protocol = "HTTPS"
  vpc_id   = var.vpc_id
}

resource "aws_lb_listener" "kibana-lb-listener" {
  load_balancer_arn = aws_lb.kibana-lb.arn
  port              = 443
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-2016-08"
  certificate_arn   = var.kibana_certificate_arn

  default_action {
    target_group_arn = aws_lb_target_group.kibana-tg.arn
    type             = "forward"
  }
}

resource "aws_lb_listener" "kibana-lb-redirect" {
  load_balancer_arn = aws_lb.kibana-lb.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type = "redirect"

    redirect {
      port        = "443"
      protocol    = "HTTPS"
      status_code = "HTTP_301"
    }
  }
}
