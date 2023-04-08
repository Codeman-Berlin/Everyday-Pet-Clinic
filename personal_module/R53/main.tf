data "aws_route53_zone" "codeman-hosted" {
  name         = var.domain_name
  private_zone = false
}

# Route53 Record
resource "aws_route53_record" "codeman_record" {
  zone_id = data.aws_route53_zone.codeman-hosted.zone_id
  name    = var.domain_name
  type    = var.record_type

  alias {
    name                   = var.lb-dns
    zone_id                = var.lb-zone-id
    evaluate_target_health = true
  }
}