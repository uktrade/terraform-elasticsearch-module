resource "aws_route53_zone" "elastic-private-zone" {
  name = var.private_hosted_zone_name

  vpc {
    vpc_id = var.vpc_id
  }
}

resource "aws_route53_record" "elastic-internal-alias" {
  zone_id = aws_route53_zone.elastic-private-zone.zone_id
  name    = "elasticsearch.${var.private_hosted_zone_name}"
  type    = "A"

  alias {
    name                   = aws_lb.main.dns_name
    zone_id                = aws_lb.main.zone_id
    evaluate_target_health = false
  }
}
