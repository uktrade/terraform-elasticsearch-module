resource "aws_lb" "main" {
  name                             = var.service_name
  load_balancer_type               = "network"
  enable_cross_zone_load_balancing = "false"

  internal = true
  subnets  = var.subnet_ids
}

resource "aws_lb_listener" "tcp" {
  load_balancer_arn = aws_lb.main.id
  port              = 9200
  protocol          = "TCP"

  default_action {
    target_group_arn = aws_lb_target_group.main.id
    type             = "forward"
  }
}

resource "aws_lb_target_group" "main" {
  name                 = var.service_name
  port                 = 9200
  protocol             = "TCP"
  vpc_id               = var.vpc_id
  target_type          = "instance"
  deregistration_delay = var.deregistration_delay

  health_check {
    protocol            = "TCP"
    interval            = var.health_check_interval
    healthy_threshold   = 5
    unhealthy_threshold = 5
  }

  depends_on = [
    aws_lb.main
  ]
}
