locals {
  subdomain = "${var.role}.${var.cluster_domain}"
}

data "aws_route53_zone" "top_level_domain" {
  name = var.cluster_domain
}

module "role_hosted_zone" {
  source  = "registry.terraform.io/terraform-aws-modules/route53/aws//modules/zones"
  version = "2.0.0"

  zones = {
    "${local.subdomain}" = {
      comment = "hosted zone for ${var.role} subdomain"
    }
  }
}

resource "aws_route53_record" "role_hosted_zone_delegation" {
  zone_id         = data.aws_route53_zone.top_level_domain.zone_id
  name            = local.subdomain
  type            = "NS"
  ttl             = 172800
  allow_overwrite = true
  records         = module.role_hosted_zone.route53_zone_name_servers[local.subdomain]
}

resource "aws_globalaccelerator_accelerator" "global_accelerator" {
  name            = "${var.role}-accelerator"
  ip_address_type = "IPV4"
  enabled         = true
}

resource "aws_globalaccelerator_listener" "listener" {
  accelerator_arn = aws_globalaccelerator_accelerator.global_accelerator.id
  client_affinity = "SOURCE_IP"
  protocol        = "TCP"

  port_range {
    from_port = 80
    to_port   = 80
  }

  port_range {
    from_port = 443
    to_port   = 443
  }
}

resource "aws_route53_record" "global_accelerator_delegation" {
  zone_id = module.role_hosted_zone.route53_zone_zone_id[local.subdomain]
  name    = local.subdomain
  type    = "A"
  ttl     = 300
  records = aws_globalaccelerator_accelerator.global_accelerator.ip_sets[0].ip_addresses
}
