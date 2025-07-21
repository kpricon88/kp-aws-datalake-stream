import boto3
import json
import os
import logging
import ast

s3 = boto3.client('s3')
logger = logging.getLogger()
logger.setLevel(logging.INFO)

CLEANSED_BUCKET = os.environ['CLEANSED_BUCKET']

def lambda_handler(event, context):
    try:
        for record in event['Records']:
            bucket = record['s3']['bucket']['name']
            key    = record['s3']['object']['key']
            logger.info(f"Processing landing object: {key}")

            response = s3.get_object(Bucket=bucket, Key=key)
            raw_content = response['Body'].read().decode('utf-8')
            raw_dict = json.loads(raw_content)
            raw_data = ast.literal_eval(raw_dict['raw_data'])
            cleaned_data = {
                "customer_id": raw_data.get("customer_id"),
                "products": raw_data.get("products"),
                "total_amount": raw_data.get("total_amount"),
                "ingested_at": raw_data.get("timestamp")
            }

            cleaned_key = key.replace("landing", "cleansed")

            s3.put_object(
                Bucket=CLEANSED_BUCKET,
                Key=cleaned_key,
                Body=json.dumps(cleaned_data),
                ContentType='application/json'
            )

            logger.info(f"Written to Cleansed S3: {cleaned_key}")
        return {"status": "cleaned and written"}

    except Exception as e:
        logger.error("Error cleansing data", exc_info=True)
        raise
