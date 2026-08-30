 locals{
    ami_id = data.aws_ami.srikanth.id
    sg_id = data.aws_ssm_parameter.sg_id.value
    private_subnet_id = split(",",data.aws_ssm_parameter.private_subnet_ids.value)[0] 
    backend_alb_listener_arn = data.aws_ssm_parameter.backend_alb_listener_arn.value
    frontend_alb_listener_arn = data.aws_ssm_parameter.frontend_alb_listener_arn.value
    alb_listener_arn = var.components == "frontend" ? local.frontend_alb_listener_arn : backend_alb_listener_arn
    vpc_id = data.aws_ssm_parameter.vpc_id.value
    common_tags = {
        project = var.project
        environment = var.environment
        terraform = true
                }
    common_name = "${var.project}-${var.environment}-${var.components}"
    host_header = var.components == "frontend" ? "${var.project}-${var.environment}-${var.domain_name}" : "${var.components}-backend-alb-${var.environment}.${var.domain_name}"
}
