output "zone_id" {
    value = data.aws_route53_zone.codeman-hosted.id 
  
}

output "zone_name" {
    value = data.aws_route53_zone.codeman-hosted.name
}