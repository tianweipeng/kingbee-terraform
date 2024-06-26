variable "profile" {
  default = "default"
}

#Region
variable "region" {
  default = "cn-shanghai"
}

#copy keys to ECS
locals {
  user_data_ecs = <<TEOF
#!/bin/bash
cp ~/.ssh/authorized_keys /root/.ssh
TEOF
}

provider "alicloud" {
  region  = var.region
  profile = var.profile
}

#VPC
module "vpc" {
  source  = "alibaba/vpc/alicloud"
  region  = var.region
  profile = var.profile
  vpc_name = "ecs_terraform"
  vpc_cidr          = "10.10.0.0/16"
  availability_zones = ["cn-shanghai-b"]
  vswitch_cidrs      = ["10.10.1.0/24"]
}

#security_group
module "security_group" {
  source  = "alibaba/security-group/alicloud"
  profile = var.profile
  region  = var.region
  vpc_id  = module.vpc.this_vpc_id

  ingress_cidr_blocks = ["0.0.0.0/0"]
  ingress_ports = [22]

  ingress_with_cidr_blocks_and_ports = [
    {
      protocol    = "tcp"
      priority    = 1
      description = "ingress for ssh"
    }
  ]
}

#ECS
module "ecs" {
  source  = "alibaba/ecs-instance/alicloud"
  profile = var.profile
  region  = var.region
  internet_max_bandwidth_out  = 1
  associate_public_ip_address = true

  name                        = "terraform_ecs"
  image_id                    = "centos_7_9_x64_20G_alibase_20201228.vhd"
  instance_type               = "ecs.t5-c1m2.xlarge"  
  vswitch_id                  = module.vpc.this_vswitch_ids.0
  security_group_ids          = [module.security_group.this_security_group_id]

  system_disk_size     = 30
  number_of_instances = 3  

  user_data = local.user_data_ecs
}

#setup ~/.ssh/config
resource "local_file" "ssh_config" {
    content     = <<EOF
%{ for ip in module.ecs.this_public_ip }
Host ecs${index(module.ecs.this_public_ip, ip) + 1}
    StrictHostKeyChecking no
    HostName ${ip}
    User terraform
%{ endfor }
EOF
    filename = "/home/shell/.ssh/config"
}

#output
resource "local_file" "info" {
    content     =  <<EOF

%{ for ip in module.ecs.this_public_ip }
ssh root@ecs${index(module.ecs.this_public_ip, ip) + 1}%{ endfor }

%{ for ip in module.ecs.this_public_ip }
ecs${index(module.ecs.this_public_ip, ip) + 1}:    ${ip}%{ endfor }

%{ for ip in module.ecs.this_private_ip }
ecs${index(module.ecs.this_private_ip, ip) + 1}:    ${ip}%{ endfor }

destroy:
cd /home/shell/terraform_ecs
terraform destroy --auto-approve
EOF
    filename = "/home/shell/terraform_ecs/readme.txt"
}

output "info" {
   value = <<EOF

%{ for ip in module.ecs.this_public_ip }
ssh root@ecs${index(module.ecs.this_public_ip, ip) + 1}%{ endfor }

%{ for ip in module.ecs.this_public_ip }
ecs${index(module.ecs.this_public_ip, ip) + 1}:    ${ip}%{ endfor }

%{ for ip in module.ecs.this_private_ip }
ecs${index(module.ecs.this_private_ip, ip) + 1}:    ${ip}%{ endfor }

cd /home/shell/terraform_ecs
terraform destroy --auto-approve

查看以上信息:
cat /home/shell/terraform_ecs/readme.txt

EOF
}
