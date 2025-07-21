import boto3
import json
import os
import logging
from datetime import datetime
import uuid

s3 = boto3.client('s3')
DEST_BUCKET = os.environ['DEST_BUCKET']

logger = logging.getLogger()
logger.setLevel(logging.INFO)

dynamodb = boto3.resource('dynamodb')
audit_table = dynamodb.Table('kp_dynamo_audit_tbl')

def write_audit(event_type, status, target_path):
    audit_item = {
        "event_id": str(uuid.uuid4()),
        "event_type": event_type,
        "status": status,
        "target": target_path,
        "timestamp": datetime.utcnow().isoformat()
    }
    audit_table.put_item(Item=audit_item)

def lambda_handler(event, context):
    try:
        for record in event['Records']:
            event_name = record['eventName']
            if event_name in ['INSERT', 'MODIFY']:
                logger.info(f"Processing {event_name} event")
                new_image = record['dynamodb']['NewImage']
                item = {k: list(v.values())[0] for k, v in new_image.items()}
                now = datetime.utcnow()
                partition_path = f"{now.year}/{now.month:02}/{now.day:02}"
                object_key = f"{partition_path}/{item['id']}.json"

                s3.put_object(
                    Bucket=DEST_BUCKET,
                    Key=object_key,
                    Body=json.dumps(item),
                    ContentType='application/json'
                )
                write_audit(event_type="INSERT", status="sent", target_path=f"s3://{DEST_BUCKET}/{object_key}")
                logger.info(f"Written to S3: {object_key}")

        return {"status": "done"}

    except Exception as e:
        logger.error("Error processing Dynamo stream", exc_info=True)
        write_audit(event_type="INSERT", status="fail", target_path="N/A")
        raise
