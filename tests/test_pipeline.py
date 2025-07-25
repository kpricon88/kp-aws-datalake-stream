# test_pipeline.py
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
    item = {
        'PK': {'S': 'user#001'},
        'SK': {'S': 'session#2025072401'},
        'eventType': {'S': 'click'},
        'timestamp': {'S': str(int(time.time()))},
        'details': {'S': json.dumps({"page": "home", "action": "view"})}
    }
    dynamo.put_item(TableName=dynamo_table_name, Item=item)
    return item['PK']['S'], item['SK']['S']

def get_latest_s3_object(bucket_name):
    response = s3.list_objects_v2(Bucket=bucket_name)
    if "Contents" in response:
        sorted_files = sorted(response["Contents"], key=lambda x: x["LastModified"], reverse=True)
        return s3.get_object(Bucket=bucket_name, Key=sorted_files[0]["Key"])
    return None

# ========== TESTS ==========

def test_pipeline_execution():
    # Step 1: Put test record into DynamoDB
    pk, sk = put_test_record()

    # Step 2: Wait for the pipeline to process
    time.sleep(60)  # Allow Lambda triggers to complete

    # Step 3: Check S3 landing bucket
    landing_file = get_latest_s3_object(s3_landing_bucket)
    assert landing_file is not None, "Landing file not found in S3"
    landing_data = landing_file["Body"].read().decode("utf-8")
    assert pk in landing_data, "PK missing in landing zone file"

    # Step 4: Check Cleansed bucket
    cleansed_file = get_latest_s3_object(s3_cleansed_bucket)
    assert cleansed_file is not None, "Cleansed file not found"
    cleansed_data = cleansed_file["Body"].read().decode("utf-8")
    assert pk in cleansed_data, "PK missing in cleansed zone file"

    # Step 5: Check Golden bucket
    golden_file = get_latest_s3_object(s3_golden_bucket)
    assert golden_file is not None, "Golden file not found"
    golden_data = golden_file["Body"].read().decode("utf-8")
    assert pk in golden_data, "PK missing in golden zone file"


def test_dlq_error_flow():
    # Send a malformed record to Dynamo (simulate failure)
    malformed_item = {
        'PK': {'S': 'bad#record'},  # Missing SK or other attributes
    }
    dynamo.put_item(TableName=dynamo_table_name, Item=malformed_item)

    time.sleep(60)  # Wait for retries and DLQ processing

    # Validate that DLQ has a message
    response = sqs.receive_message(QueueUrl=dql_queue_url, MaxNumberOfMessages=1)
    assert "Messages" in response, "No message found in DLQ"
    dlq_message = response["Messages"][0]
    assert "bad#record" in dlq_message["Body"], "Malformed record not found in DLQ"
    
    # Optional cleanup: Delete DLQ message
    sqs.delete_message(QueueUrl=dql_queue_url, ReceiptHandle=dlq_message["ReceiptHandle"])


if __name__ == "__main__":
    pytest.main(["-v", "test_pipeline.py"])
