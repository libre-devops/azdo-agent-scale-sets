variable "helper_script_folder" {
  type        = string
  default     = "C:\\Program Files\\WindowsPowerShell\\Modules\\"
  description = "Name of helper script folder"
}

variable "image_folder" {
  type        = string
  default     = "C:\\image"
  description = "Name of Image folder"
}

variable "image_os" {
  type        = string
  default     = "win19"
  description = "OS flag"
}

variable "image_version" {
  type        = string
  default     = "dev"
  description = "Image version name"
}

variable "imagedata_file" {
  type        = string
  default     = "C:\\imagedata.json"
  description = "Place for image date"

}

variable "install_password" {
  type        = string
  sensitive   = true
  default     = env("PKR_VAR_install_password")
  description = "Name of user to run scripts"
}

variable "install_user" {
  type        = string
  default     = "installer"
  description = "Name of user to run scripts"
}

variable "vm_size" {
  type        = string
  default     = "Standard_B4ms"
  description = "Packer orchestrated build Vm size"
}

variable "location" {
  type        = string
  default     = "UK South"
  description = "Used in scripts"
}

// Uses the packer env inbuilt function - https://www.packer.io/docs/templates/hcl_templates/functions/contextual/env
variable "client_id" {
  type        = string
  description = "The client id, passed as a PKR_VAR"
  default     = env("PKR_VAR_client_id")
}

variable "client_secret" {
  type        = string
  sensitive   = true
  description = "The client_secret, passed as a PKR_VAR"
  default     = env("PKR_VAR_client_secret")
}

variable "dockerhub_login" {
  type        = string
  description = "The docker hub login, passed as a PKR_VAR"
  default     = env("PKR_VAR_dockerhub_login")
}

variable "dockerhub_password" {
  type        = string
  description = "The docker hub password passed as a PKR_VAR"
  sensitive   = true
  default     = env("PKR_VAR_dockerhub_password")
}

variable "subscription_id" {
  type        = string
  description = "The gallery resource group name, passed as a PKR_VAR"
  default     = env("PKR_VAR_subscription_id")
}

variable "tenant_id" {
  type        = string
  description = "The gallery resource group name, passed as a PKR_VAR"
  default     = env("PKR_VAR_tenant_id")
}

variable "gallery_name" {
  type        = string
  default     = "galldouksdev01"
  description = "The gallery name"
}

variable "gallery_rg_name" {
  type        = string
  default     = "rg-ldo-uks-dev-build"
  description = "The gallery resource group name"
}


locals {
  install_password = trim(uuidv4(), "-")
}

source "azure-arm" "build" {
  client_id                 = var.client_id
  client_secret             = var.client_secret
  subscription_id           = var.subscription_id
  tenant_id                 = var.tenant_id
  build_resource_group_name = var.gallery_rg_name

  // The sku you want to base your image off - In this case - Ubuntu 22
  os_type         = "Windows"
  image_publisher = "MicrosoftWindowsServer"
  image_offer     = "WindowsServer"
  image_sku       = "2019-Datacenter"
  vm_size         = "Standard_D4s_v4"

  winrm_insecure = "true"
  winrm_use_ssl  = "true"
  winrm_username = "packer"

  // Name of Image which is created by Terraform
  managed_image_name                = "lbdo-azdo-ubuntu-22.04"
  managed_image_resource_group_name = var.gallery_rg_name

  // Shared image gallery is created by terraform in the pre-req step, as is the resource group.
  shared_image_gallery_destination {
    gallery_name   = var.gallery_name
    image_name     = "lbdo-azdo-windows-2019"
    image_version  = formatdate("YYYY.MM.DD", timestamp())
    resource_group = var.gallery_rg_name
    subscription   = var.subscription_id
    replication_regions = [
      "uksouth"
    ]
  }

}

build {
  sources = ["source.azure-arm.build"]

  provisioner "powershell" {
    inline = ["New-Item -Path ${var.image_folder} -ItemType Directory -Force"]
  }

  provisioner "file" {
    destination = "${var.helper_script_folder}"
    source      = "${path.root}/scripts/ImageHelpers"
  }

  provisioner "file" {
    destination = "${var.image_folder}"
    source      = "${path.root}/scripts/SoftwareReport"
  }

  provisioner "file" {
    destination = "C:/"
    source      = "${path.root}/post-generation"
  }

  provisioner "file" {
    destination = "${var.image_folder}"
    source      = "${path.root}/scripts/Tests"
  }

  provisioner "file" {
    destination = "${var.image_folder}\\toolset.json"
    source      = "${path.root}/toolsets/toolset-2019.json"
  }

  provisioner "windows-shell" {
    inline = [
      "net user ${var.install_user} ${var.install_password} /add /passwordchg:no /passwordreq:yes /active:yes /Y",
      "net localgroup Administrators ${var.install_user} /add",
      "winrm set winrm/config/service/auth @{Basic=\"true\"}",
      "winrm get winrm/config/service/auth"
    ]
  }

  provisioner "powershell" {
    inline = ["if (-not ((net localgroup Administrators) -contains '${var.install_user}')) { exit 1 }"]
  }

  provisioner "powershell" {
    elevated_password = "${var.install_password}"
    elevated_user     = "${var.install_user}"
    inline            = ["bcdedit.exe /set TESTSIGNING ON"]
  }

  provisioner "powershell" {
    environment_vars = ["IMAGE_VERSION=${var.image_version}", "IMAGE_OS=${var.image_os}", "AGENT_TOOLSDIRECTORY=${var.agent_tools_directory}", "IMAGEDATA_FILE=${var.imagedata_file}"]
    execution_policy = "unrestricted"
    scripts = [
      "${path.root}/scripts/Installers/Configure-Antivirus.ps1",
      "${path.root}/scripts/Installers/Install-PowerShellModules.ps1",
      "${path.root}/scripts/Installers/Install-WindowsFeatures.ps1",
      "${path.root}/scripts/Installers/Install-Choco.ps1",
      "${path.root}/scripts/Installers/Initialize-VM.ps1",
      "${path.root}/scripts/Installers/Update-ImageData.ps1",
      "${path.root}/scripts/Installers/Update-DotnetTLS.ps1"
    ]
  }

  provisioner "windows-restart" {
    restart_timeout = "30m"
  }

  provisioner "powershell" {
    scripts = [
      "${path.root}/scripts/Installers/Install-VCRedist.ps1",
      "${path.root}/scripts/Installers/Install-Docker.ps1",
      "${path.root}/scripts/Installers/Install-PowershellCore.ps1",
      "${path.root}/scripts/Installers/Install-WebPlatformInstaller.ps1"
    ]
  }

  provisioner "windows-restart" {
    restart_timeout = "10m"
  }

  provisioner "powershell" {
    elevated_password = "${var.install_password}"
    elevated_user     = "${var.install_user}"
    scripts = [
      "${path.root}/scripts/Installers/Install-VS.ps1",
      "${path.root}/scripts/Installers/Install-KubernetesTools.ps1",
      "${path.root}/scripts/Installers/Install-NET48.ps1"
    ]
    valid_exit_codes = [0, 3010]
  }

  provisioner "powershell" {
    scripts = [
      "${path.root}/scripts/Installers/Install-Wix.ps1",
      "${path.root}/scripts/Installers/Install-WDK.ps1",
      "${path.root}/scripts/Installers/Install-Vsix.ps1",
      "${path.root}/scripts/Installers/Install-AzureCli.ps1",
      "${path.root}/scripts/Installers/Install-AzureDevOpsCli.ps1",
      "${path.root}/scripts/Installers/Install-CommonUtils.ps1",
      "${path.root}/scripts/Installers/Install-JavaTools.ps1",
      "${path.root}/scripts/Installers/Install-Kotlin.ps1"
    ]
  }

  provisioner "powershell" {
    execution_policy = "remotesigned"
    scripts          = ["${path.root}/scripts/Installers/Install-ServiceFabricSDK.ps1"]
  }

  provisioner "windows-restart" {
    restart_timeout = "10m"
  }

  provisioner "windows-shell" {
    inline = ["wmic product where \"name like '%%microsoft azure powershell%%'\" call uninstall /nointeractive"]
  }

  provisioner "powershell" {
    scripts = [
      "${path.root}/scripts/Installers/Install-Ruby.ps1",
      "${path.root}/scripts/Installers/Install-PyPy.ps1",
      "${path.root}/scripts/Installers/Install-Toolset.ps1",
      "${path.root}/scripts/Installers/Configure-Toolset.ps1",
      "${path.root}/scripts/Installers/Install-AzureModules.ps1",
      "${path.root}/scripts/Installers/Install-Pipx.ps1",
      "${path.root}/scripts/Installers/Install-PipxPackages.ps1",
      "${path.root}/scripts/Installers/Install-Git.ps1",
      "${path.root}/scripts/Installers/Install-GitHub-CLI.ps1",
      "${path.root}/scripts/Installers/Install-Chrome.ps1",
      "${path.root}/scripts/Installers/Install-Edge.ps1",
      "${path.root}/scripts/Installers/Install-Firefox.ps1",
      "${path.root}/scripts/Installers/Install-Selenium.ps1",
      "${path.root}/scripts/Installers/Install-IEWebDriver.ps1",
      "${path.root}/scripts/Installers/Install-Apache.ps1",
      "${path.root}/scripts/Installers/Install-Nginx.ps1",
      "${path.root}/scripts/Installers/Install-Msys2.ps1",
      "${path.root}/scripts/Installers/Install-WinAppDriver.ps1",
      "${path.root}/scripts/Installers/Install-SQLPowerShellTools.ps1",
      "${path.root}/scripts/Installers/Install-DotnetSDK.ps1",
      "${path.root}/scripts/Installers/Install-Mingw64.ps1",
      "${path.root}/scripts/Installers/Install-Zstd.ps1",
      "${path.root}/scripts/Installers/Install-NSIS.ps1",
      "${path.root}/scripts/Installers/Install-Vcpkg.ps1",
      "${path.root}/scripts/Installers/Install-RootCA.ps1",
      "${path.root}/scripts/Installers/Disable-JITDebugger.ps1",
      "${path.root}/scripts/Installers/Configure-DynamicPort.ps1",
      "${path.root}/scripts/Installers/Configure-GDIProcessHandleQuota.ps1",
      "${path.root}/scripts/Installers/Configure-Shell.ps1",
      "${path.root}/scripts/Installers/Enable-DeveloperMode.ps1",
      "${path.root}/scripts/Installers/Install-LLVM.ps1"
    ]
  }

  provisioner "powershell" {
    elevated_password = "${var.install_password}"
    elevated_user     = "${var.install_user}"
    scripts           = ["${path.root}/scripts/Installers/Install-WindowsUpdates.ps1"]
  }

  provisioner "windows-restart" {
    check_registry        = true
    restart_check_command = "powershell -command \"& {if ((-not (Get-Process TiWorker.exe -ErrorAction SilentlyContinue)) -and (-not [System.Environment]::HasShutdownStarted) ) { Write-Output 'Restart complete' }}\""
    restart_timeout       = "30m"
  }

  provisioner "powershell" {
    pause_before = "2m0s"
    scripts      = ["${path.root}/scripts/Installers/Wait-WindowsUpdatesForInstall.ps1", "${path.root}/scripts/Tests/RunAll-Tests.ps1"]
  }

  provisioner "powershell" {
    inline = ["if (-not (Test-Path ${var.image_folder}\\Tests\\testResults.xml)) { throw '${var.image_folder}\\Tests\\testResults.xml not found' }"]
  }

  provisioner "powershell" {
    environment_vars = ["IMAGE_VERSION=${var.image_version}"]
    inline           = ["pwsh -File '${var.image_folder}\\SoftwareReport\\SoftwareReport.Generator.ps1'"]
  }

  provisioner "powershell" {
    inline = ["if (-not (Test-Path C:\\InstalledSoftware.md)) { throw 'C:\\InstalledSoftware.md not found' }"]
  }

  provisioner "powershell" {
    scripts    = ["${path.root}/scripts/Installers/Run-NGen.ps1", "${path.root}/scripts/Installers/Finalize-VM.ps1"]
    skip_clean = true
  }

  provisioner "windows-restart" {
    restart_timeout = "10m"
  }

  provisioner "powershell" {
    inline = [
      "if( Test-Path $Env:SystemRoot\\System32\\Sysprep\\unattend.xml ){ rm $Env:SystemRoot\\System32\\Sysprep\\unattend.xml -Force}",
      "& $env:SystemRoot\\System32\\Sysprep\\Sysprep.exe /oobe /generalize /quiet /quit",
    "while($true) { $imageState = Get-ItemProperty HKLM:\\SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\Setup\\State | Select ImageState; if($imageState.ImageState -ne 'IMAGE_STATE_GENERALIZE_RESEAL_TO_OOBE') { Write-Output $imageState.ImageState; Start-Sleep -s 10  } else { break } }"]
  }

}
