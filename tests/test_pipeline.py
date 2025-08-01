import boto3
import json
import time
import pytest

# ========== SETUP ==========
region = "us-east-1"
dynamo = boto3.client("dynamodb", region_name=region)
s3 = boto3.client("s3", region_name=region)
sqs = boto3.client("sqs", region_name=region)
lambda_client = boto3.client("lambda", region_name=region)

dynamo_table_name = "kp-dynamo-landing-tbl"
s3_landing_bucket = "dynamodb-landing-zone-example"
s3_cleansed_bucket = "dynamodb-cleansed-zone-example"
s3_golden_bucket = "s3-golden-bucket-kp-dev"
dql_queue_url = "https://sqs.us-east-1.amazonaws.com/692859950441/lambda-dlq-queue"

# ========== HELPERS ==========
def put_test_record():
    """Insert a valid and traceable record into DynamoDB."""
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

# ========== TESTS ==========

def test_pipeline_execution():
    # Step 1: Put test record into DynamoDB
    record_id = put_test_record()

    # Step 2: Wait for the pipeline to process
    time.sleep(60)  # Allow Lambda and Glue to run

    # Step 3: Check S3 landing bucket
    landing_file = get_latest_s3_object(s3_landing_bucket)
    assert landing_file is not None, "Landing file not found in S3"
    landing_data = landing_file["Body"].read().decode("utf-8")
    assert record_id in landing_data, "Record ID missing in landing zone file"

    # Step 4: Check Cleansed bucket
    cleansed_file = get_latest_s3_object(s3_cleansed_bucket)
    assert cleansed_file is not None, "Cleansed file not found"
    cleansed_data = cleansed_file["Body"].read().decode("utf-8")
    assert record_id in cleansed_data, "Record ID missing in cleansed zone file"

    # Step 5: Check Golden bucket
    golden_file = get_latest_s3_object(s3_golden_bucket)
    assert golden_file is not None, "Golden file not found"
    golden_data = golden_file["Body"].read().decode("utf-8")
    assert record_id in golden_data, "Record ID missing in golden zone file"

def test_dlq_error_flow():
    """Send a syntactically valid but semantically invalid record to trigger DLQ."""
    malformed_item = {
        'id': {'S': 'bad#record'},
        'srt_ky': {'S': 'bad#sortkey'},
        'raw_data': {'S': 'INVALID_JSON_STRING'}  # Intentionally bad payload
    }
    dynamo.put_item(TableName=dynamo_table_name, Item=malformed_item)

    time.sleep(60)  # Wait for retries and DLQ routing

    # Check DLQ for message
    response = sqs.receive_message(QueueUrl=dql_queue_url, MaxNumberOfMessages=1)
    assert "Messages" in response, "No message found in DLQ"
    dlq_message = response["Messages"][0]
    assert "bad#record" in dlq_message["Body"], "Malformed record not found in DLQ"

    # Optional cleanup
    sqs.delete_message(QueueUrl=dql_queue_url, ReceiptHandle=dlq_message["ReceiptHandle"])

# ========== ENTRY POINT ==========
if __name__ == "__main__":
    pytest.main(["-v", "test_pipeline.py"])