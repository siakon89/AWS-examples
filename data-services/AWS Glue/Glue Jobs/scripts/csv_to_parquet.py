import logging
import sys
from urllib.parse import urlparse

import boto3
from awsglue.context import GlueContext
from awsglue.job import Job
from awsglue.transforms import ApplyMapping
from awsglue.utils import getResolvedOptions
from pyspark.context import SparkContext

# Configure logging to suppress INFO logs
logging.getLogger("py4j").setLevel(logging.ERROR)
logging.getLogger("org.apache.spark").setLevel(logging.ERROR)
logging.getLogger("org.spark_project").setLevel(logging.ERROR)
logging.getLogger("org.apache.hadoop").setLevel(logging.ERROR)

sc = SparkContext()
sc.setLogLevel("ERROR")
glueContext = GlueContext(sc)
spark = glueContext.spark_session
job = Job(glueContext)

# Get job parameters
args = getResolvedOptions(sys.argv, ["JOB_NAME", "input_path", "output_path"])

job.init(args["JOB_NAME"], args)

# Log job parameters
input_path = args["input_path"]
output_path = args["output_path"]

print(f"Input path: {input_path}")
print(f"Output path: {output_path}")


def get_glue_type_name(spark_type):
    type_mapping = {
        "StringType": "string",
        "IntegerType": "int",
        "LongType": "long",
        "DoubleType": "double",
        "FloatType": "float",
        "DecimalType": "decimal",
        "BooleanType": "boolean",
        "TimestampType": "timestamp",
        "DateType": "date",
        "ArrayType": "array",
        "MapType": "map",
        "StructType": "struct",
        "BinaryType": "binary",
        "ShortType": "short",
        "ByteType": "byte",
    }

    type_name = spark_type.__class__.__name__
    return type_mapping.get(type_name, "string")


def process_csv_to_parquet():
    """
    Read CSV data from S3, transform it, and write as Parquet with optional partitioning
    """
    print(f"Reading CSV data from {input_path}")
    spark_df = spark.read.option("header", "true").option("inferSchema", "true").csv(
        input_path
    )
    column_names = spark_df.columns

    # Get data types from Spark DataFrame
    spark_schema = spark_df.schema
    column_types = {field.name: field.dataType for field in spark_schema}

    print("Inferred data types:")
    for col, dtype in column_types.items():
        print(f"  {col}: {dtype}")

    # Use GlueContext to read the data
    dynamic_frame = glueContext.create_dynamic_frame.from_options(
        connection_type="s3",
        connection_options={
            "paths": [input_path],
            "recurse": True,
        },
        format="csv",
        format_options={
            "withHeader": True,
            "separator": ",",
            "optimizePerformance": True,
            "quoteChar": '"',
            "escapeChar": "\\",
            "columnNameOfCorruptRecord": "_corrupt_record",
        },
    )

    if dynamic_frame.count() == 0:
        raise Exception("Dynamic frame is empty. Please check the input file.")

    # Show sample records
    print("Sample records:")
    dynamic_frame.show(5)

    # Get the schema from the dynamic frame
    schema = dynamic_frame.schema()
    field_names = [field.name for field in schema.fields]

    # Create mapping to ensure column names and types are preserved
    if len(field_names) == len(column_names):
        # Create a mapping for ApplyMapping transform
        mapping = []
        for field_name, desired_name in zip(field_names, column_names):
            # Get the correct data type from Spark DataFrame if available
            if desired_name in column_types:
                spark_type = column_types[desired_name]
                glue_type = get_glue_type_name(spark_type)
                mapping.append((field_name, glue_type, desired_name, glue_type))
                print(
                    f"Mapping {field_name} ({glue_type}) -> {desired_name} ({glue_type})"
                )
            else:
                # Fallback to string if type cannot be determined
                mapping.append((field_name, "string", desired_name, "string"))
                print(f"Mapping {field_name} (string) -> {desired_name} (string)")

        print(f"Applying mapping: {mapping}")
        mapped_dyf = ApplyMapping.apply(frame=dynamic_frame, mappings=mapping)

        # Verify the mapping worked
        print("Schema after mapping:")
        mapped_dyf.printSchema()
    else:
        raise Exception(
            "Column names do not match between Spark DataFrame and dynamic frame."
        )

    # Show sample records
    print("Sample records:")
    mapped_dyf.show(5)

    # Write the data in Parquet format
    glueContext.write_dynamic_frame.from_options(
        frame=mapped_dyf,
        connection_type="s3",
        connection_options={"path": output_path},
        format="parquet",
        transformation_ctx="write_parquet",
    )

    # Get record count
    record_count = mapped_dyf.count()
    print(
        f"Successfully converted {record_count} records from CSV to Parquet at {output_path}"
    )


# Execute the job
process_csv_to_parquet()

# Commit the job
job.commit() 