packer {
  required_plugins {
    azure = {
      source  = "github.com/hashicorp/azure"
      version = "~> 2"
    }
  }
}

// Variable Declarations
variable "use_azure_cli_auth" {
  description = <<-EOD
                Use Azure CLI authentication. Defaults to false. CLI auth will use the information from an active az login session to connect to Azure and set the subscription id and tenant id associated to the signed in account.
                If enabled, it will use the authentication provided by the az CLI. Azure CLI authentication will use the credential marked as isDefault and can be verified using az account show.
                Works with normal authentication (az login) and service principals (az login --service-principal --username APP_ID --password PASSWORD --tenant TENANT_ID). Ignores all other configurations if enabled.
                EOD
  type        = bool
  default     = false
}
variable "tenant_id" {
  description = "The Active Directory tenant identifier with which your [client_id] and [subscription_id] are associated. If not specified, [tenant_id] will be looked up using [subscription_id]."
  type        = string
  default     = ""
}
variable "subscription_id" {
  description = "The subscription Idto use."
  type        = string
  default     = ""
}
variable "cloud_environment_name" {
  description = "One of Public, China, or USGovernment. Defaults to Public. Long Forms such as USGovernmentCloud and AzureUSGovernmentCloud are also supported."
  type        = string
  default     = "Public"
}
variable "metadata_host" {
  description = <<-EOD
                The Hostname of the Azure Metadata Service (for example management.azure.com), used to obtain the Cloud Environment when using a Custom Azure Environment.
                IMPORTANT: [cloud_environment_name] must be set to a name in the list of available environments held in the metadata_host.
                EOD
  type        = string
  default     = ""
}
variable "location" {
  description = <<-EOD
                The Azure region where the VM and resources will be created to generate the image.
                This will also be the default location for the [acg_image_version_replication_regions].
                IMPORTANT: Can not be used if [build_resource_group_name] is specified.
                EOD
  type = string
  default = ""
}
variable "build_name" {
  description = "The optional name of the build. Named builds will prefix the log lines in a packer build with the name of the build block."
  type        = string
  default     = ""
}
variable "build_resource_group_name" {
  description = <<-EOD
                Specify an existing resource group to run the build in. If not specified, Packer generates a random resource group.
                IMPORTANT: Cannot specify [location] if you set this variable.
                EOD
  type = string
  default = ""
}
variable "client_id" {
  description = "The application ID of the AAD Service Principal. Requires either [client_secret], [client_cert_path] or [client_jwt] to be set as well."
  sensitive = true
  type      = string
  default   = ""
}
variable "client_secret" {
  description = "A password/secret registered for the AAD SP."
  sensitive = true
  type      = string
  default   = ""
}
variable "environment" {
  description = "a three digit identifier for the environment for which the image is created."
  type    = string
  default = "Dev"
}
# Source Image parameters
variable "image_offer" {
  description = "Name of the publisher's offer to use for your base image (Azure Marketplace Images only)."
  type = string
}
variable "image_publisher" {
  description = "Name of the publisher to use for your base image (Azure Marketplace Images only)."
  type = string
}
variable "image_sku" {
  description = "SKU of the image offer to use for your base image (Azure Marketplace Images only)."
  type = string
}
# Azure Compute Gallery Destination parameters
variable "acg_name" {
  description = "The name of the Azure Compute Gallery."
  type = string
}
variable "acg_resource_group_name" {
  description = "The resource group name containing the Azure Compute Gallery."
  type = string
}
variable "acg_image_definition_name" {
  description = "The name of the image definition in the Azure Compute Gallery for which a new version will be created."
  type = string
}
variable "acg_image_version" {
  type        = string
  description = <<-EOD
                The Azure Compute Gallery Image Definition image version specified with numbers and periods only in the format: MajorVersion.MinorVersion.Patch
                Defaults to using the time that packer was executed in the following format: YYYY.MMDD.hhmm
                EOD
  default     = ""
}
variable "acg_image_version_replication_regions" {
  description = <<-EOD
                List of regions where the image version should be replicated. Defaults to [location].
                IMPORTANT: Must be set if [location] is not set.
                EOD
  type        = list(string)
  default     = []
}
variable "acg_image_version_replica_count" {
  description = <<-EOD
                The number of replicas of the Image Version to be created per region.
                This property would take effect for a region when regionalReplicaCount is not specified.
                Replica count must be between 1 and 100, but 50 replicas should be sufficient for most use cases.
                EOD
  type        = number
  default     = 1
}
variable "vmSize" {
  type    = string
  default = "Standard_D4ads_v5"
}
variable "user_assigned_managed_identities" {
  description = <<-EOF
                A list of one or more fully-qualified resource IDs of user assigned managed identities to be configured on the VM.
                IMPORTANT: The first one in the list must be the identity used to access the storage account containing the provisioning scripts.
                To assign a user assigned managed identity to a VM, the account running the deployment must have Managed Identity Operator and Virtual Machine Contributor role assignments.
                EOF
  type        = list(string)
  default     = []  
}
variable "virtual_network_name" {
  description = "Use a pre-existing virtual network for the VM. This option enables private communication with the VM, no public IP address is used or provisioned."
  type        = string
  default     = ""
}
variable "virtual_network_subnet_name" {
  description = <<-EOD
                If virtual_network_name is set, this value may also be set. If [virtual_network_name] is set, and this value is not set the builder attempts to determine the subnet to use with the virtual network.
                If the subnet cannot be found, or it cannot be disambiguated, this value should be set.
                EOD
  type        = string
  default     = ""
}
variable "virtual_network_resource_group_name" {
  description = <<-EOD
                If virtual_network_name is set, this value may also be set.
                If [virtual_network_name] is set, and this value is not set the builder attempts to determine the resource group containing the virtual network.
                If the resource group cannot be found, or it cannot be disambiguated, this value should be set.
                EOD
  type        = string
  default     = ""
}
variable "artifacts_container_url" {
  description = "The url of the blob container where the image script sources are stored. This will be prepended to the [blobs] list and sent as an environment variable to the master image build script."
  type        = string
  default     = ""
}
variable "files_download" {
  description = "A list of file names from blob storage or absolute Uris names that will processed by the master build script."
  type        = list(string)
  default     = []
}
variable "files_upload" {
  type        = list(string)
  description = "a list of files that will be uploaded to the build VM using WinRM. This is only suitable for small files. Use only the file names from the directory specified by the local [artifacts_dir]"
  default     = []
}
variable "master_buildscript_variables" {
  type        = map(string)
  description = <<-EOD
                A list of key-value pairs that will be injected into the Build VM as environment variables.
                IMPORTANT: Always use the following format (without the <> placeholders): {"pkr_<stringVariable>":"<StringValue>","pkr_<intVariable>":<intValue>,"pkr_<boolVariable>:<$true or $false>}
                The packer_windows_master_script will build the [hashtable]$DynParameters variable which will be sent to each additional script as a parameter.
                Therefore you can send custom parameters and values to your own custom scripts. Your script can get the value by using the following code:
                   $SampleVariable = $DynParameter.KeyName
                EOD
  default     = {}
}

locals {
  artifacts_dir             = "${path.cwd}/../artifacts" // ${path.cwd} is the path of packer 
  build_dir                 = "c:/buildartifacts/" // path on vm where the provisioners upload/download files for execution/usage.
  files_upload              = [for file in var.files_upload : "${local.artifacts_dir}/${file}"] // automatically prepend the local artifacts directory.
  build_script              = "${local.artifacts_dir}/packer_master_script.ps1" // the master build script that will be uploaded by packer and ran on the VM.
  files_download            = "${var.files_download != [] ? join(",", var.files_download) : null}"
  azure_environment         = "${lookup({"Public":"AzureCloud","USGovernment":"AzureUSGovernment"}, var.cloud_environment_name, "AzureCloud")}" // Lookup table to convert Packer to Azure environment names.
  build_script_defvariables = {"pkr_AzureEnvironment":"${local.azure_environment}","pkr_BuildDir":"${local.build_dir}","pkr_Environment":"${var.environment}","pkr_ImageVersion":"${var.acg_image_version}"} 
  build_script_variables    = "${var.files_download != [] ? merge(local.build_script_defvariables, {"pkr_DownloadFiles":"${local.files_download}"}, {"pkr_ArtifactsContainerUrl":"${var.artifacts_container_url}"}, {"pkr_StorageMIResId":"${var.user_assigned_managed_identities[0]}"}, var.master_buildscript_variables) : merge(local.build_script_defvariables, var.master_buildscript_variables)}"
  image_replication_regions = "${var.location != "" ? setunion(var.acg_image_version_replication_regions, [var.location]) : var.acg_image_replication_regions}"
}

source "azure-arm" "imageBuild" {
  cloud_environment_name    = var.cloud_environment_name
  metadata_host             = "${var.metadata_host != "" ? var.metadata_host : null}"
  use_azure_cli_auth        = "${var.use_azure_cli_auth ? true : false}"
  tenant_id                 = "${var.tenant_id != "" ? var.tenant_id : null}"
  subscription_id           = "${var.subscription_id != "" ? var.subscription_id : null}"
  client_id                 = "${var.client_id != "" ? var.client_id : null}"
  client_secret             = "${var.client_secret != "" ? var.client_secret : null}"

  location                  = "${var.location != "" ? var.build_resource_group_name == "" ? var.location : null : null}"
  build_resource_group_name = "${var.build_resource_group_name != "" ? var.build_resource_group_name : null}"

  # Marketplace Image Source
  image_offer     = var.image_offer
  image_publisher = var.image_publisher
  image_sku       = var.image_sku

  os_type             = "Windows"
  # Security Profile
  secure_boot_enabled = true
  vtpm_enabled        = true
  vm_size             = var.vmSize
  communicator        = "winrm"
  winrm_insecure      = true
  winrm_timeout       = "7m"
  winrm_use_ssl       = true
  winrm_username      = "packer"
  user_assigned_managed_identities = "${var.user_assigned_managed_identities != [] ? var.user_assigned_managed_identities : null}"

  virtual_network_name = "${var.virtual_network_name != "" ? var.virtual_network_name : null}"
  virtual_network_subnet_name = "${var.virtual_network_subnet_name != "" ? var.virtual_network_subnet_name : null}"
  virtual_network_resource_group_name = "${var.virtual_network_resource_group_name != "" ? var.virtual_network_resource_group_name : null}"

  shared_image_gallery_destination {
    gallery_name        = var.acg_name
    image_name          = var.acg_image_definition_name
    image_version       = "${var.acg_image_version != "" ? var.acg_image_version : formatdate("YYYY.MMDD.hhmm", timestamp())}"
    replication_regions = local.image_replication_regions
    resource_group      = var.acg_resource_group_name
  }
  shared_image_gallery_replica_count = "${var.acg_image_version_replica_count != "" ? var.acg_image_version_replica_count : null}"

  azure_tags = {
    "Env"             = var.environment
    "Image Offer"     = var.image_offer
    "Image Publisher" = var.image_publisher
    "Image SKU"       = var.image_sku
    "Task"            = "Packer"
  }
}

build {
  name    = "${var.build_name != "" ? var.build_name : var.build_resource_group_name != "" ? var.build_resource_group_name : "Dynamic_Windows" }"
  sources = ["source.azure-arm.imageBuild"]
 
  provisioner "file" {
    sources     = local.files_upload
    destination = local.build_dir
  }

  provisioner "powershell" {
    elevated_user     = "SYSTEM"
    elevated_password = ""
    env               = local.build_script_variables
    script            = local.build_script
  }

  provisioner "powershell" {
    elevated_user     = "SYSTEM"
    elevated_password = ""
    inline            = ["If (Test-Path -Path ${local.build_dir}){remove-item -path ${local.build_dir} -recurse -erroraction silentlycontinue}"]
  }

  provisioner "windows-update" {
    search_criteria = "IsInstalled=0"
    filters = [
      "exclude:$_.Title -like '*Preview*'",
      "include:$true",
    ]
    update_limit = 25
  }

  # Initiating a system restart
  provisioner "windows-restart" {
    restart_check_command = "powershell -command \"& {Write-Output 'Restarted'}\""
    pause_before          = "10s"
  }

  # Generalizing the image
  provisioner "powershell" {
    elevated_user     = "SYSTEM"
    elevated_password = ""
    inline = [
      <<-EOS
        Write-host '=== Azure image build completed successfully ==='
        Write-host '=== Generalizing the image ==='
        while ((Get-Service RdAgent).Status -ne 'Running') { Start-Sleep -s 5 }
        while ((Get-Service WindowsAzureGuestAgent).Status -ne 'Running') { Start-Sleep -s 5 }
        & $env:SystemRoot\\System32\\Sysprep\\Sysprep.exe /oobe /generalize /quiet /quit
        while($true) {
          $imageState = Get-ItemProperty HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Setup\State | Select ImageState
          if($imageState.ImageState -ne 'IMAGE_STATE_GENERALIZE_RESEAL_TO_OOBE') {
            Write-Output $imageState.ImageState
            Start-Sleep -s 10
          } else {
            Write-Output $imageState.ImageState
            Break
          }
        }
        EOS
    ]
  }
}