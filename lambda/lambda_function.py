import boto3
from datetime import datetime, timedelta
import json

s3 = boto3.client("s3")
ce = boto3.client("ce")

BUCKET = "aws-cost-dashboard-laszlobanreti"  # CloudFront mögötti S3 bucket

def lambda_handler(event, context):
    end = datetime.utcnow().date()
    start = end - timedelta(days=7)

    response = ce.get_cost_and_usage(
        TimePeriod={"Start": start.strftime("%Y-%m-%d"), "End": end.strftime("%Y-%m-%d")},
        Granularity="DAILY",
        Metrics=["UnblendedCost"]
    )

    total = sum(
        float(day["Total"]["UnblendedCost"]["Amount"])
        for day in response["ResultsByTime"]
    )

    data = {
        "period": f"{start} - {end}",
        "total": round(total, 2)
    }

    # Mentés S3-ba
    s3.put_object(
        Bucket=BUCKET,
        Key="cost.json",
        Body=json.dumps(data),
        ContentType="application/json"
    )

    return {"status": "ok", "total": total}
