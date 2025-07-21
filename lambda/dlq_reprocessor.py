import json
import logging
import os

logger = logging.getLogger()
logger.setLevel(os.environ.get("LOG_LEVEL", "INFO"))

def lambda_handler(event, context):
    for record in event['Records']:
        try:
            payload = json.loads(record['body'])
            logger.error("Processing DLQ record: %s", json.dumps(payload))
            # Optionally retry original logic here
        except Exception as e:
            logger.exception(f"Failed to process DLQ record: {str(e)}")