# Auto Scaling Group
resource "aws_autoscaling_group" "codeman_ASG_QA" {
name = var.asg-group-name
max_size                  = 4
min_size                  = 2
desired_capacity          = 2
health_check_grace_period = 300
health_check_type         = "EC2"
force_delete              = true
launch_configuration      = aws_launch_configuration.codeman_launch_config_QA.id
vpc_zone_identifier       = [var.vpc_subnet1, var.vpc_subnet2]
target_group_arns         = [var.lb_arn]
tag{
    key = "Name"
    value = "stage_docker_asg"
    propagate_at_launch = true
}
}

# Auto Scaling Group Policy
resource "aws_autoscaling_policy" "codeman_ASG_POLICY_QA" {
name  = var.asg-policy
adjustment_type = "ChangeInCapacity"
policy_type = "TargetTrackingScaling"
autoscaling_group_name = aws_autoscaling_group.codeman_ASG_QA.id
target_tracking_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ASGAverageCPUUtilization"
    }
    target_value = 60.0
  }    
}
#creating ASG Launch Configuration
resource "aws_launch_configuration" "codeman_launch_config_QA" {
  name          = var.lc_name
  image_id      = var.amiLC
  instance_type = var.lc_instance_type
  associate_public_ip_address = true
  security_groups = [var.asg_sg]
  key_name = var.key_pair
  user_data              = file("./personal_module/Stage_Auto_Scaling_Group/docker.sh")
}
