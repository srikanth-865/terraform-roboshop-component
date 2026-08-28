resource "aws_instance" "main" {
  ami           = local.ami_id
  instance_type = "t3.micro"
  subnet_id     = local.private_subnet_id
  vpc_security_group_ids      = [local.sg_id] #in the data.tf we give component name dynamically so we get as per that

  tags = merge(
    {
        Name = "${local.common_name}" #Roboshop1-Dev-Catalogue
    },
local.common_tags,
  )
}

resource "terraform_data" "main" {
  # Re-run if the instance ID or IP changes
  triggers_replace =  [
    aws_instance.main.id,
  ]
  
  connection {
    type        = "ssh"
    user        = "ec2-user"
    password = "DevOps321"
    host        = aws_instance.main.private_ip
  }

# 2. Copy a single local file to a remote destination
  provisioner "file" {
    source      = "script.sh"
    destination = "/tmp/script.sh"
  }
  provisioner "remote-exec" {
    inline = [
       "chmod +x /tmp/script.sh",
       "sudo  sh /tmp/script.sh ${var.components} ${var.environment} ${var.app_version}"
    
    ]
  }
}
 
/* resource "aws_ec2_instance_state" "main" {   
  instance_id = aws_instance.main.id
  state       = "stopped"
  depends_on = [terraform_data.main]   #its for stopping the instance after completing of terraform data
}

resource "aws_ami_from_instance" "main" {  #creating ami for catalogue instance
  name               ="${local.common_name}-${var.app_version}-${aws_instance.main.id}"  #Roboshop1-Dev-catalogue-v3-id..
  source_instance_id = aws_instance.main.id
  depends_on = [aws_ec2_instance_state.main]   #its for after stopping the instance state then it will run this ami creation resource

   tags = merge(
    local.common_tags,
    {
        Name = "${local.common_name}-${var.app_version}-${aws_instance.main.id}"
    }
  )

}


#creating launch template 

resource "aws_launch_template" "main" {
  name = "${local.common_name}"
  image_id = aws_ami_from_instance.main.id  #AMI ID
  instance_initiated_shutdown_behavior = "terminate"
  vpc_security_group_ids = [local.sg_id]
  update_default_version = true
  instance_type = "t3.micro"

#Once the instances are created this will become instance tags
  tag_specifications {
    resource_type = "instance"

    tags =  merge(
    local.common_tags,
    {
        Name = "${local.common_name}-${var.app_version}-${aws_instance.main.id}"
    }
  )
  }

#Once the instances are created this will become volume tags
   tag_specifications {
    resource_type = "volume"

    tags =  merge(
    local.common_tags,
    {
        Name = "${local.common_name}-${var.app_version}-${aws_instance.main.id}"
    }
  )
  }

 #this for launch template resource tags
 tags =  merge(
    local.common_tags,
    {
        Name = "${local.common_name}-${var.app_version}-${aws_instance.main.id}"
    }
  )
}

resource "aws_lb_target_group" "main" {
  name     = "${local.common_name}"
  port     = var.components == "frontend" ? "80" : "8080"
  protocol = "HTTP"
  vpc_id   = local.vpc_id

   # Time in seconds for releasing instances in the target group 
  deregistration_delay = 30 #seconds

    health_check {
    enabled             = true
    path                = var.components == "frontend" ? "/" : "/health"
    protocol            = "HTTP"
    port                = 8080
    interval            = 10
    timeout             = 5 #secs
    healthy_threshold   = 2
    unhealthy_threshold = 2 
    matcher             = "200-299" #status success
  }
}

resource "aws_autoscaling_group" "main" {
  name_prefix         = "${local.common_name}"
  min_size            = 1  #atlesat 1 instance for running
  max_size            = 10 #we can go upto 10 instnaces
  desired_capacity    = 2 #we want 2 instances
  vpc_zone_identifier = [local.private_subnet_id[0]] # Replace with your Subnet IDs
   force_delete              = false
  health_check_type         = "ELB"
  health_check_grace_period = 120 # for 2 min we can decide instances healthy

  launch_template { 
    id      = aws_launch_template.main.id
    version = "$Latest"
  }
  target_group_arns = [aws_lb_target_group.main.arn] # Autoscaling launches into specific target group catalogue 

 # Forces instances to rolling-update when launch template changes
  instance_refresh {
    strategy = "Rolling"
    preferences {
      min_healthy_percentage = 50
    }
    triggers = ["launch_template"]
  }

#for Autoscaling resource is providing only tag with dynamic map values so we create dynamic block

dynamic "tag" {
  for_each = merge(
    {
      Name = "${local.common_name}"
    },
    local.common_tags
  )

  content {
      key                 = tag.key
      value               = tag.value
      propagate_at_launch = true
    }
    }


  # with in 15min autoscaling should be successful to launch instances
  timeouts {
    delete = "15m"
  }
}

 # Attach the Target Tracking Policy
resource "aws_autoscaling_policy" "main" {
  name                   = "${local.common_name}"
  autoscaling_group_name = aws_autoscaling_group.main.name   #attahing catalogue group to this policy
  policy_type            = "TargetTrackingScaling"
   estimated_instance_warmup = 120  #for 2 min of instance checking
  target_tracking_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ASGAverageCPUUtilization"
    }
  

    target_value = 75.0  #Average CPU utilization = 70% then when CPU utilization goes above 70%, Auto Scaling can scale out (add instances) to bring the average CPU back toward 70%.
}
}

resource "aws_lb_listener_rule" "main" {
  listener_arn = local.alb_listener_arn  #we attach our loadbalancer _alb arn based on components
  priority     = var.rule_priority # we can give our priority 

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.main.arn  #we give to our target group catalogue forwarding 
  }

  condition {
    host_header {
      values = [local.host_header]   #based on our components it will and condition based on locals
    }
  }
}


resource "terraform_data" "main_delete" {
  triggers_replace = [
    aws_instance.main.id
  ]
  depends_on = [aws_autoscaling_policy.main]

  # executes where terraform is running
  provisioner "local-exec" {
    command = "aws ec2 terminate-instances --instance-ids ${aws_instance.main.id}"
  }
}


