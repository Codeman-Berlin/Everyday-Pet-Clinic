# VPC
module "vpc" {
  source                 = "terraform-aws-modules/vpc/aws"
  name                   = var.vpc_name
  cidr                   = var.vpc_cidr
  azs                    = [var.az1, var.az2]
  private_subnets        = [var.prv-sn1, var.prv-sn2]
  public_subnets         = [var.pub-sn1, var.pub-sn2]
  enable_nat_gateway     = true
  single_nat_gateway     = false
  one_nat_gateway_per_az = true
  tags = {
    Terraform = "true"
    Name      = "${var.name}-vpc"
  }
}

# Security Group
module "sg" {
  source = "./personal_module/sg"
  vpc    = module.vpc.vpc_id
}

# Keypair
module "key_pair" {
  source     = "terraform-aws-modules/key-pair/aws"
  key_name   = var.keyname
  public_key = file("~/keypairs/Codeman.pub")
}

# Bastion Host Instance
module "Bastion" {
  source                 = "terraform-aws-modules/ec2-instance/aws"
  name                   = var.ec2_name
  ami                    = var.ec2_ami
  instance_type          = var.instancetype
  key_name               = module.key_pair.key_pair_name
  vpc_security_group_ids = [module.sg.bastion-sg-id]
  subnet_id              = module.vpc.public_subnets[0]
  user_data = templatefile("./User-data/Bastion.sh",
    {
      keypair = "~/keypairs/Codeman"
    }
  )
  tags = {
    Terraform = "true"
    Name      = "${var.name}-Bastion"
  }
}

# Docker Instance
module "Docker" {
  source                 = "terraform-aws-modules/ec2-instance/aws"
  name                   = var.ec2_name
  ami                    = var.ec2_ami
  instance_type          = var.instancetype
  key_name               = module.key_pair.key_pair_name
  vpc_security_group_ids = [module.sg.docker-sg-id]
  subnet_id              = module.vpc.private_subnets[0]
  count                  = 2
  user_data = templatefile("./User-data/Docker.sh", {
    new_relic_key = var.new_relic_key
  })

  tags = {
    Terraform = "true"
    Name      = "${var.docker_name}${count.index}"
  }
}

# Continuous Testing Instance
module "Cont_Instance" {
  source                 = "terraform-aws-modules/ec2-instance/aws"
  name                   = var.ec2_name
  ami                    = var.ec2_ami
  instance_type          = var.instancetype
  key_name               = module.key_pair.key_pair_name
  vpc_security_group_ids = [module.sg.docker-sg-id]
  subnet_id              = module.vpc.private_subnets[0]
  user_data              = file("./User-data/Cont_Instance.sh")
  tags = {
    Terraform = "true"
    Name      = "${var.name}-Cont_Instance"
  }
}


# Jenkins Instance
module "Jenkins" {
  source                 = "terraform-aws-modules/ec2-instance/aws"
  name                   = var.ec2_name
  ami                    = var.ec2_ami
  instance_type          = var.instancetype
  key_name               = module.key_pair.key_pair_name
  vpc_security_group_ids = [module.sg.jenkins-sg-id]
  subnet_id              = module.vpc.private_subnets[0]
  user_data = templatefile("./User-data/Jenkins.sh", {
    new_relic_key = var.new_relic_key
  })
  tags = {
    Terraform = "true"
    Name      = "${var.name}-Jenkins"
  }
}

# Elastic Load balancer for Jenkins
module "jenkins_elb" {
  source      = "./personal_module/Jenkins_elb"
  subnet_id1  = module.vpc.public_subnets[0]
  subnet_id2  = module.vpc.public_subnets[1]
  security_id = module.sg.alb-sg-id
  jenkins_id  = module.Jenkins.id
}

# Production Server ELB
module "Prod_elb" {
  source      = "./personal_module/Prod_elb"
  subnet_id1  = module.vpc.public_subnets[0]
  subnet_id2  = module.vpc.public_subnets[1]
  security_id = module.sg.alb-sg-id
  Prod_id     = module.Docker[1].id
}

# ec2_iam
module "ec2_iam" {
  source = "./personal_module/ec2_iam"
}

# Ansible Instance (QA & Prod)
module "Ansible" {
  source                 = "terraform-aws-modules/ec2-instance/aws"
  name                   = var.ec2_name
  ami                    = var.ec2_ami
  iam_instance_profile   = module.ec2_iam.iam-profile-name
  instance_type          = var.instancetype
  key_name               = module.key_pair.key_pair_name
  vpc_security_group_ids = [module.sg.ansible-sg-id]
  subnet_id              = module.vpc.private_subnets[0]

  user_data = templatefile("./User-data/Ansible.sh",
    {
      keypair              = "~/keypairs/Codeman",
      STAGEcontainer       = "./playbooks/STAGEcontainer.yml",
      stage_auto_discovery = "./playbooks/stage_auto_discovery.yml",
      stage_runner         = "./playbooks/stage_runner.yml",
      PRODcontainer        = "./playbooks/PRODcontainer.yml",
      PROD_Auto_Discovery  = "./playbooks/PROD_Auto_Discovery.yml",
      PROD_runner          = "./playbooks/PROD_runner.yml",
      vault_password       = "./playbooks/Vault_IP.yml",
      new_relic_key        = var.new_relic_key,
      doc_pass             = var.doc_pass,
      doc_user             = var.doc_user,
    }
  )
  tags = {
    Terraform = "true"
    Name      = "${var.name}-Ansible"
  }
}

# SonarQube Instance
module "Sonarqube" {
  source                 = "terraform-aws-modules/ec2-instance/aws"
  name                   = var.sonar-name
  ami                    = var.ec2_ami
  instance_type          = var.instancetype
  key_name               = module.key_pair.key_pair_name
  vpc_security_group_ids = [module.sg.sonarqube-sg-id]
  subnet_id              = module.vpc.public_subnets[0]
  user_data              = file("./User-data/Sonar.sh")
  tags = {
    Terraform = "true"
    Name      = "${var.name}-sonar-instance"
  }
}

# Application Load Balancer
module "App_loadbalancer" {
  source          = "./personal_module/App_loadbalancer"
  lb_security     = module.sg.alb-sg-id
  lb_subnet1      = module.vpc.public_subnets[0]
  lb_subnet2      = module.vpc.public_subnets[1]
  vpc_name        = module.vpc.vpc_id
  target_instance = module.Docker[1].id
}

# Stage Application Load Balancer
module "Stage_App_loadbalancer" {
  source          = "./personal_module/Stage_App_loadbalancer"
  lb_security     = module.sg.alb-sg-id
  lb_subnet1      = module.vpc.public_subnets[0]
  lb_subnet2      = module.vpc.public_subnets[1]
  vpc_name        = module.vpc.vpc_id
  target_instance = module.Docker[1].id
}

# Auto Scaling Group
module "Auto_Scaling_Group" {
  source              = "./personal_module/Auto_Scaling_Group"
  vpc_subnet1         = module.vpc.public_subnets[0]
  vpc_subnet2         = module.vpc.public_subnets[1]
  lb_arn              = module.App_loadbalancer.lb_tg
  asg_sg              = module.sg.docker-sg-id
  key_pair            = module.key_pair.key_pair_name
  ami_source_instance = module.Docker[1].id
}

# Stage Auto Scaling Group
module "Stage_Auto_Scaling_Group" {
  source      = "./personal_module/Stage_Auto_Scaling_Group"
  vpc_subnet1 = module.vpc.public_subnets[0]
  vpc_subnet2 = module.vpc.public_subnets[1]
  lb_arn      = module.Stage_App_loadbalancer.lb_tg
  asg_sg      = module.sg.docker-sg-id
  key_pair    = module.key_pair.key_pair_name
  amiLC       = module.Auto_Scaling_Group.ami
}

# Database
module "db" {
  source                 = "terraform-aws-modules/rds/aws"
  identifier             = "codemandb"
  engine                 = "mysql"
  engine_version         = "5.7"
  instance_class         = "db.t3.medium"
  allocated_storage      = 5
  db_name                = "codemanDB"
  username               = "admin"
  password               = "admin"
  port                   = "3306"
  vpc_security_group_ids = [module.sg.mysql-sg-id]
  tags = {
    Owner       = "user"
    Environment = "dev"
  }
  # DB subnet group
  create_db_subnet_group = true
  subnet_ids             = [module.vpc.private_subnets[0], module.vpc.private_subnets[1]]
  # DB parameter group
  family = "mysql5.7"
  # DB option group
  major_engine_version = "5.7"
  # Database Deletion Protection
  deletion_protection = false
}

# AWS Certificate Manager
module "AWS_ACM" {
  source           = "./personal_module/AWS_ACM"
  lb_arn           = module.App_loadbalancer.lb_arn
  lb_target_arn    = module.App_loadbalancer.lb_tg
  lb-zone-id       = module.App_loadbalancer.lb_zone_id
  prod-lb-dns      = module.App_loadbalancer.lb_DNS
  stage-lb-dns     = module.Stage_App_loadbalancer.lb_DNS
  stage-lb-zone-id = module.Stage_App_loadbalancer.lb_zone_id
  lb_target_arn2   = module.Stage_App_loadbalancer.lb_tg
  lb_arn2          = module.Stage_App_loadbalancer.lb_arn
}

# Route53 & Alias Record
module "R53" {
  source     = "./personal_module/R53"
  lb-zone-id = module.App_loadbalancer.lb_zone_id
  lb-dns     = module.App_loadbalancer.lb_DNS
}





