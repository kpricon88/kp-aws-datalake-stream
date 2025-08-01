import boto3
import json
import time
import pytest

region = "us-east-1"
dynamo = boto3.client("dynamodb", region_name=region)
s3 = boto3.client("s3", region_name=region)

dynamo_table_name = "kp-dynamo-landing-tbl"
s3_landing_bucket = "dynamodb-landing-zone-example"
s3_cleansed_bucket = "dynamodb-cleansed-zone-example"
s3_golden_bucket = "s3-golden-bucket-kp-dev"

def put_test_record():
    unique_id = f"user#{int(time.time())}"
    item = {
        'id': {'S': unique_id},
        'srt_ky': {'S': f'session#{int(time.time())}'},
        'raw_data': {'S': json.dumps({
            "test_id": unique_id,
            "page": "home",
            "action": "view",
            "eventType": "click"
        })}
    }
    dynamo.put_item(TableName=dynamo_table_name, Item=item)
    return unique_id

def get_latest_s3_object(bucket_name):
    response = s3.list_objects_v2(Bucket=bucket_name)
    if "Contents" in response:
        sorted_files = sorted(response["Contents"], key=lambda x: x["LastModified"], reverse=True)
        return s3.get_object(Bucket=bucket_name, Key=sorted_files[0]["Key"])
    return None

def test_pipeline_execution():
    record_id = put_test_record()
    time.sleep(60)

    landing_file = get_latest_s3_object(s3_landing_bucket)
    assert landing_file is not None, "Landing file not found in S3"
    landing_data = landing_file["Body"].read().decode("utf-8")
    assert record_id in landing_data, "Record ID missing in landing zone file"
