locals {
  # Raw layer: every column is a string (schema-on-read). Types are cast in dbt staging.
  ks4_subject_columns = [
    "time_period",
    "time_identifier",
    "geographic_level",
    "country_code",
    "country_name",
    "release_status", # the CSV calls this "version"; renamed so it doesn't clash with the partition key
    "establishment_type_group",
    "breakdown_topic",
    "sex",
    "qualification_type",
    "subject",
    "grade",
    "total_exam_entries",
    "percentage_achieving",
  ]
}

resource "aws_glue_catalog_table" "raw_ks4_subject_timeseries" {
  name          = "raw_ks4_subject_timeseries"
  database_name = aws_glue_catalog_database.main.name
  table_type    = "EXTERNAL_TABLE"

  parameters = {
    EXTERNAL                 = "TRUE"
    classification           = "csv"
    "skip.header.line.count" = "1"
  }

  partition_keys {
    name = "version"
    type = "string"
  }

  storage_descriptor {
    location      = "s3://${aws_s3_bucket.raw.bucket}/dfe/ks4_subject_timeseries/"
    input_format  = "org.apache.hadoop.mapred.TextInputFormat"
    output_format = "org.apache.hadoop.hive.ql.io.HiveIgnoreKeyTextOutputFormat"

    ser_de_info {
      serialization_library = "org.apache.hadoop.hive.serde2.lazy.LazySimpleSerDe"
      parameters = {
        "field.delim" = ","
      }
    }

    dynamic "columns" {
      for_each = local.ks4_subject_columns
      content {
        name = columns.value
        type = "string"
      }
    }
  }
}