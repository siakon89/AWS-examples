locals {
    # AWS Region
    aws_region = "eu-central-1"

    # Resource naming
    name        = "<the name of the project>"
    environment = "demo"

    # Tags
    tags = {
        Environment = local.environment
        Project     = "Athena Showcase"
        Terraform   = "true"
    }

    # Sample data
    sample_data_prefix      = "<the prefix of the sample data that you put in the S3 bucket>"

    # Athena Workgroup configuration
    athena_workgroup = {
        enforce_workgroup_configuration    = true
        publish_cloudwatch_metrics_enabled = true
        encryption_option                  = "SSE_S3"
        bytes_scanned_cutoff_per_query     = 0
        # Available engine versions:
        # - "AUTO" (automatically selects the latest engine version)
        # - "Athena engine version 3" (latest SQL engine version)
        # - "PySpark engine version 3" (for running PySpark queries)
        engine_version                     = "Athena engine version 3"
    }
}