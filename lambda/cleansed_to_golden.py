import boto3
import json
import os
import logging
from collections import defaultdict

s3 = boto3.client('s3')
logger = logging.getLogger()
logger.setLevel(logging.INFO)

GOLDEN_BUCKET = os.environ['GOLDEN_BUCKET']

def lambda_handler(event, context):
    try:
        logger.info("Received event: %s", json.dumps(event))

        agg_data = defaultdict(list)
        record_count = len(event.get('Records', []))
        logger.info(f"Processing {record_count} records from S3 event")

        for record in event['Records']:
            bucket = record['s3']['bucket']['name']
            key    = record['s3']['object']['key']
            logger.info(f"Reading for aggregation from bucket: {bucket}, key: {key}")

            try:
                response = s3.get_object(Bucket=bucket, Key=key)
                raw = response['Body'].read().decode('utf-8')
                logger.debug(f"Raw S3 content: {raw}")
                data = json.loads(raw)
            except Exception as read_err:
                logger.error(f"Failed to read or parse S3 object: {key}", exc_info=True)
                continue

            customer_id = data.get('customer_id')
            if not customer_id:
                logger.warning(f"Missing customer_id in record: {data}")
                continue

            agg_data[customer_id].append(data)
            logger.info(f"Added transaction for customer {customer_id}")

        if not agg_data:
            logger.warning("No valid customer_id found in any record.")

        for customer_id, entries in agg_data.items():
            logger.info(f"Aggregating {len(entries)} entries for customer: {customer_id}")

            golden_key = f"golden/{customer_id}/summary.json"
            summary = {
                "customer_id": customer_id,
                "total_transactions": len(entries),
                "total_spent": sum(entry.get("total_amount", 0) for entry in entries),
                "products_bought": list({item for entry in entries for item in entry.get("products", [])}),
                "timestamps": [entry.get("ingested_at", "unknown") for entry in entries]
            }

            s3.put_object(
                Bucket=GOLDEN_BUCKET,
                Key=golden_key,
                Body=json.dumps(summary),
                ContentType='application/json'
            )
            logger.info(f"Golden summary written for customer: {customer_id} -> s3://{GOLDEN_BUCKET}/{golden_key}")

        return {"status": "aggregated to golden"}

    except Exception as e:
        logger.error("Error aggregating to golden", exc_info=True)
        raise