locals {
  project_name = "<project-name>"
  environment  = "<environment>"
  region       = "<region>"

  # Common tags
  tags = {
    Project     = local.project_name
    Environment = local.environment
    ManagedBy   = "terraform"
  }
} 
