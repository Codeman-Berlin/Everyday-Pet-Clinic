output "asg" {
    value = aws_autoscaling_group.codeman_ASG.id
}

output "ami" {
    value = aws_ami_from_instance.codeman_ami.id
}