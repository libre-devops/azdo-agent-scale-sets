variable "capture_name_prefix" {
  type    = string
  default = "packer"
}

variable "client_id" {
  type = string
}

variable "client_secret" {
  type      = string
  sensitive = true
}

variable "dockerhub_login" {
  type        = string
  description = "The docker hub login, passed as a PKR_VAR"
}

variable "dockerhub_password" {
  type        = string
  description = "The docker hub password passed as a PKR_VAR"
}

variable "helper_script_folder" {
  type    = string
  default = "/imagegeneration/helpers"
}

variable "image_folder" {
  type    = string
  default = "/imagegeneration"
}

variable "image_os" {
  type    = string
  default = "ubuntu22"
}

variable "image_version" {
  type    = string
  default = "dev"
}

variable "imagedata_file" {
  type    = string
  default = "/imagegeneration/imagedata.json"
}

variable "installer_script_folder" {
  type    = string
  default = "/imagegeneration/installers"
}

variable "install_password" {
  type    = string
  default = ""
}

variable "location" {
  type    = string
  default = "West Europe"
}

variable "subscription_id" {
  type        = string
  description = "The gallery resource group name, passed as a PKR_VAR"
}

variable "tenant_id" {
  type        = string
  description = "The gallery resource group name, passed as a PKR_VAR"
}

variable "gallery_name" {
  type        = string
  default     = "galldoeuwdev01"
  description = "The gallery name"
}

variable "gallery_rg_name" {
  type        = string
  default     = "rg-ldo-euw-dev-build"
  description = "The gallery resource group name, passed as a PKR_VAR"
}

source "azure-arm" "build" {

  client_id                 = var.client_id
  client_secret             = var.client_secret
  subscription_id           = var.subscription_id
  tenant_id                 = var.tenant_id
  build_resource_group_name = var.gallery_rg_name
  user_data_file            = "./scripts/base/configure-legacy-ssh.sh" # Needed due to bug https://github.com/hashicorp/packer/issues/11656

  // The sku you want to base your image off - In this case - Ubuntu 22
  os_type                 = "Linux"
  image_publisher         = "Canonical"
  image_offer             = "0001-com-ubuntu-server-jammy"
  image_sku               = "22_04-lts"
  vm_size                 = "Standard_D4s_v4"
  temporary_key_pair_type = "ed25519"

  // Name of Image which is created by Terraform
  managed_image_name                = "lbdo-azdo-ubuntu-22.04"
  managed_image_resource_group_name = var.gallery_rg_name

  shared_image_gallery_destination {
    gallery_name   = var.gallery_name
    image_name     = "lbdo-azdo-ubuntu-22.04"
    image_version  = formatdate("YYYY.MM.DD", timestamp())
    resource_group = var.gallery_rg_name
    subscription   = var.subscription_id
    replication_regions = [
      "westeurope"
    ]
  }
}

build {
  sources = ["source.azure-arm.build"]

  # Creates a folder for the prep of the image - Needed
  provisioner "shell" {
    execute_command = "sudo sh -c '{{ .Vars }} {{ .Path }}'"
    inline          = ["mkdir ${var.image_folder}", "chmod 777 ${var.image_folder}"]
  }

  # Fixes an error in the Linux machine which causes the WALinuxAgent to break - https://github.com/Azure/azure-linux-extensions/issues/1238 - Needed
  provisioner "shell" {
    execute_command = "sudo sh -c '{{ .Vars }} {{ .Path }}'"
    script          = "${path.root}/scripts/base/apt-mock.sh"
  }

  # Adds various repos to the image, such as the Microsoft one - Needed
  provisioner "shell" {
    environment_vars = ["DEBIAN_FRONTEND=noninteractive"]
    execute_command  = "sudo sh -c '{{ .Vars }} {{ .Path }}'"
    scripts          = ["${path.root}/scripts/base/repos.sh"]
  }

  # Preps a bunch of apt services - Needed
  provisioner "shell" {
    environment_vars = ["DEBIAN_FRONTEND=noninteractive"]
    execute_command  = "sudo sh -c '{{ .Vars }} {{ .Path }}'"
    script           = "${path.root}/scripts/base/apt.sh"
  }

  # Sets Pam limits - Potentially Unneeded
  provisioner "shell" {
    execute_command = "sudo sh -c '{{ .Vars }} {{ .Path }}'"
    script          = "${path.root}/scripts/base/limits.sh"
  }

  # Creates folder - Needed
  provisioner "file" {
    destination = "${var.helper_script_folder}"
    source      = "${path.root}/scripts/helpers"
  }

  # Creates folder - Needed
  provisioner "file" {
    destination = "${var.installer_script_folder}"
    source      = "${path.root}/scripts/installers"
  }

  # Creates folder - Needed
  provisioner "file" {
    destination = "${var.image_folder}"
    source      = "${path.root}/post-generation"
  }

  # Creates folder - Needed
  provisioner "file" {
    destination = "${var.image_folder}"
    source      = "${path.root}/scripts/tests"
  }

  # Creates folder - Needed
  provisioner "file" {
    destination = "${var.image_folder}"
    source      = "${path.root}/scripts/SoftwareReport"
  }

  # Loads JSON file with toolset within
  provisioner "file" {
    destination = "${var.installer_script_folder}/toolset.json"
    source      = "${path.root}/toolsets/toolset-2204.json"
  }

  # Primes image data file - Probably Unneeded
  provisioner "shell" {
    environment_vars = ["IMAGE_VERSION=${var.image_version}", "IMAGEDATA_FILE=${var.imagedata_file}"]
    execute_command  = "sudo sh -c '{{ .Vars }} {{ .Path }}'"
    scripts          = ["${path.root}/scripts/installers/preimagedata.sh"]
  }

  # Configures OS environment - Needed
  provisioner "shell" {
    environment_vars = ["IMAGE_VERSION=${var.image_version}", "IMAGE_OS=${var.image_os}", "HELPER_SCRIPTS=${var.helper_script_folder}"]
    execute_command  = "sudo sh -c '{{ .Vars }} {{ .Path }}'"
    scripts          = ["${path.root}/scripts/installers/configure-environment.sh"]
  }

  # Configures Snapstore (ew) - Needed
  provisioner "shell" {
    environment_vars = ["HELPER_SCRIPTS=${var.helper_script_folder}"]
    execute_command  = "sudo sh -c '{{ .Vars }} {{ .Path }}'"
    scripts          = ["${path.root}/scripts/installers/complete-snap-setup.sh", "${path.root}/scripts/installers/powershellcore.sh"]
  }

  # Install PowerShell Modules - Needed
  provisioner "shell" {
    environment_vars = ["HELPER_SCRIPTS=${var.helper_script_folder}", "INSTALLER_SCRIPT_FOLDER=${var.installer_script_folder}"]
    execute_command  = "sudo sh -c '{{ .Vars }} pwsh -f {{ .Path }}'"
    scripts          = ["${path.root}/scripts/installers/Install-PowerShellModules.ps1", "${path.root}/scripts/installers/Install-AzureModules.ps1"]
  }

  # Installs Docker and Docker-Compose via Moby - Needed
  provisioner "shell" {
    environment_vars = ["HELPER_SCRIPTS=${var.helper_script_folder}", "INSTALLER_SCRIPT_FOLDER=${var.installer_script_folder}", "DOCKERHUB_LOGIN=${var.dockerhub_login}", "DOCKERHUB_PASSWORD=${var.dockerhub_password}"]
    execute_command  = "sudo sh -c '{{ .Vars }} {{ .Path }}'"
    scripts          = ["${path.root}/scripts/installers/docker-compose.sh", "${path.root}/scripts/installers/docker-moby.sh"]
  }

  # Installs packages added in the installers dir
  provisioner "shell" {
    environment_vars = ["HELPER_SCRIPTS=${var.helper_script_folder}", "INSTALLER_SCRIPT_FOLDER=${var.installer_script_folder}", "DEBIAN_FRONTEND=noninteractive"]
    execute_command  = "sudo sh -c '{{ .Vars }} {{ .Path }}'"
    scripts = [
      "${path.root}/scripts/installers/azcopy.sh",
      "${path.root}/scripts/installers/azure-cli.sh",
      "${path.root}/scripts/installers/azure-devops-cli.sh",
      "${path.root}/scripts/installers/basic.sh",
      "${path.root}/scripts/installers/containers.sh",
      "${path.root}/scripts/installers/dotnetcore-sdk.sh",
      "${path.root}/scripts/installers/git.sh",
      "${path.root}/scripts/installers/github-cli.sh",
      "${path.root}/scripts/installers/kubernetes-tools.sh",
      "${path.root}/scripts/installers/terraform.sh",
      "${path.root}/scripts/installers/packer.sh",
      "${path.root}/scripts/installers/vcpkg.sh",
      "${path.root}/scripts/installers/dpkg-config.sh",
      "${path.root}/scripts/installers/yq.sh",
      "${path.root}/scripts/installers/pypy.sh",
      "${path.root}/scripts/installers/python.sh",
    ]
  }

  # Installs everything in toolset.json as part of the toolcache section (which is basically everything) - Needed
  provisioner "shell" {
    environment_vars = ["HELPER_SCRIPTS=${var.helper_script_folder}", "INSTALLER_SCRIPT_FOLDER=${var.installer_script_folder}"]
    execute_command  = "sudo sh -c '{{ .Vars }} pwsh -f {{ .Path }}'"
    scripts          = ["${path.root}/scripts/installers/Install-Toolset.ps1", "${path.root}/scripts/installers/Configure-Toolset.ps1"]
  }

  # Installs everything in the PipX section - Needed
  provisioner "shell" {
    environment_vars = ["HELPER_SCRIPTS=${var.helper_script_folder}", "INSTALLER_SCRIPT_FOLDER=${var.installer_script_folder}"]
    execute_command  = "sudo sh -c '{{ .Vars }} {{ .Path }}'"
    scripts          = ["${path.root}/scripts/installers/pipx-packages.sh"]
  }

  # Restarts the snapd - Needed
  provisioner "shell" {
    environment_vars = ["HELPER_SCRIPTS=${var.helper_script_folder}", "DEBIAN_FRONTEND=noninteractive", "INSTALLER_SCRIPT_FOLDER=${var.installer_script_folder}"]
    execute_command  = "/bin/sh -c '{{ .Vars }} {{ .Path }}'"
    scripts          = ["${path.root}/scripts/installers/homebrew.sh"]
  }

  # Restarts the snapd - Needed
  provisioner "shell" {
    execute_command = "sudo sh -c '{{ .Vars }} {{ .Path }}'"
    script          = "${path.root}/scripts/base/snap.sh"
  }

  # Reboots the VM - Needed
  provisioner "shell" {
    execute_command   = "/bin/sh -c '{{ .Vars }} {{ .Path }}'"
    expect_disconnect = true
    scripts           = ["${path.root}/scripts/base/reboot.sh"]
  }

  # Cleans up junk - Needed
  provisioner "shell" {
    execute_command     = "sudo sh -c '{{ .Vars }} {{ .Path }}'"
    pause_before        = "1m0s"
    scripts             = ["${path.root}/scripts/installers/cleanup.sh"]
    start_retry_timeout = "10m"
  }

  # Removes apt mock - Needed
  provisioner "shell" {
    execute_command = "sudo sh -c '{{ .Vars }} {{ .Path }}'"
    script          = "${path.root}/scripts/base/apt-mock-remove.sh"
  }

  # Runs Pester tests - Needed
  provisioner "shell" {
    environment_vars = ["IMAGE_VERSION=${var.image_version}", "INSTALLER_SCRIPT_FOLDER=${var.installer_script_folder}"]
    inline           = ["pwsh -File ${var.image_folder}/tests/RunAll-Tests.ps1 -OutputDirectory ${var.image_folder}"]
  }

  # Post-deployment - Needed
  provisioner "shell" {
    environment_vars = ["HELPER_SCRIPT_FOLDER=${var.helper_script_folder}", "INSTALLER_SCRIPT_FOLDER=${var.installer_script_folder}", "IMAGE_FOLDER=${var.image_folder}"]
    execute_command  = "sudo sh -c '{{ .Vars }} {{ .Path }}'"
    scripts          = ["${path.root}/scripts/installers/post-deployment.sh"]
  }

  provisioner "shell" {
    execute_command = "sudo sh -c '{{ .Vars }} {{ .Path }}'"
    inline          = ["sleep 30", "/usr/sbin/waagent -force -deprovision+user && export HISTSIZE=0 && sync"]
  }
}
