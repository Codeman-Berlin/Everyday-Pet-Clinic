output "lb_tg" {
    value = aws_lb_target_group.codeman_lb_TG_QA.arn
}

output "lb_DNS" {
    value = aws_lb.codeman_lb_QA.dns_name
}

output "lb_zone_id" {
    value = aws_lb.codeman_lb_QA.zone_id
}

output "lb_arn" {
    value = aws_lb.codeman_lb_QA.arn
}