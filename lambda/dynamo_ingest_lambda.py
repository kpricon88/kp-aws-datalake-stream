import boto3
import os
import uuid
import random
import logging
from datetime import datetime
from decimal import Decimal

dynamodb = boto3.resource('dynamodb')
table_name = os.environ['DYNAMO_TABLE']
table = dynamodb.Table(table_name)

logger = logging.getLogger()
logger.setLevel(logging.INFO)

PRODUCTS_CATALOG = [
    {"name": "Laptop", "price": 999.99},
    {"name": "Monitor", "price": 249.99},
    {"name": "Keyboard", "price": 79.99},
    {"name": "Mouse", "price": 49.99},
    {"name": "Webcam", "price": 89.99},
    {"name": "Headphones", "price": 199.99}
]

def generate_random_transaction():
    customer_id = str(uuid.uuid4())
    chosen_products = random.sample(PRODUCTS_CATALOG, random.randint(1, 3))
    total_amount = round(sum(p["price"] for p in chosen_products), 2)

    return {
        "id": str(uuid.uuid4()),
        "srt_ky": datetime.utcnow().isoformat(),
        "raw_data": {
            "customer_id": customer_id,
            "products": [p["name"] for p in chosen_products],
            "total_amount": total_amount,
            "timestamp": datetime.utcnow().strftime("%Y-%m-%d %H:%M:%S")
        }
    }

def lambda_handler(event, context):
    try:
        num_transactions = random.randint(3, 5)
        logger.info(f"Generating {num_transactions} sales transactions")

        for _ in range(num_transactions):
            record = generate_random_transaction()
            item = {
                "id": record["id"],
                "srt_ky": record["srt_ky"],
                "raw_data": str(record["raw_data"])
            }

            table.put_item(Item=item)
            logger.info(f"Inserted sale: {item}")

        return {"status": "success", "count": num_transactions}

    except Exception as e:
        logger.error("Error inserting sales transactions", exc_info=True)
        raise
