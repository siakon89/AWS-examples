locals {
  project_name = "thelastdev-glue-etl"
  environment  = "dev"
  region       = "eu-central-1"

  # Common tags
  tags = {
    Project     = local.project_name
    Environment = local.environment
    ManagedBy   = "terraform"
  }
} 
