resource "random_string" "random_suffix" {
  length  = 6
  special = false
}

locals {
  agent_pool_name = "Pool-${random_string.random_suffix.result}"
}

#resource "null_resource" "create_agent_pool" {
#  triggers = {
#    agent_pool_name = var.azdo_agent_pool_name != null ? var.azdo_agent_pool_name : local.agent_pool_name
#  }
#
#  provisioner "local-exec" {
#    command = "python3 create_pool.py --url ${var.azdo_url} --pat-token ${var.azdo_pat} --agent-pool-name ${self.triggers.agent_pool_name}"
#    interpreter = ["/bin/sh", "-c"]
#    environment = {
#      AZDO_PAT = var.azdo_pat
#      AZDO_URL = var.azdo_url
#    }
#  }
#}

data "external" "agent_pool" {
  program = ["python3", "create_pool.py"]

  query = {
    url             = var.azdo_url
    pat_token       = var.azdo_pat
    agent_pool_name = var.azdo_agent_pool_name != null ? var.azdo_agent_pool_name : local.agent_pool_name
  }
}

locals {
  agent_pool_id = data.external.agent_pool.result["agent_pool_id"]
}
