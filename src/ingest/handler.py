import urllib.request
import hashlib
import json
import os
from datetime import datetime, timezone

import boto3


DATASET_ID = "1ae39901-dc7f-3870-b08a-d398a5ecd5c4"
CSV_URL = f"https://api.education.gov.uk/statistics/v1/data-sets/{DATASET_ID}/csv"


def fetch_csv(url: str) -> bytes:
    """Download the dataset CSV exactly as served (gzip-compressed bytes)."""
    request = urllib.request.Request(url, headers={"Accept-Encoding": "gzip"})
    with urllib.request.urlopen(request, timeout=30) as response:
        return response.read()

RAW_BUCKET = os.environ.get("RAW_BUCKET", "learnline-raw-369970405316")
PREFIX = "dfe/ks4_subject_timeseries"


def build_key(ingest_date: str, filename: str) -> str:
    """Hive-style partition path, e.g. dfe/.../ingest_date=2026-10-20/data.csv.gz"""
    return f"{PREFIX}/ingest_date={ingest_date}/{filename}"


def upload(s3, body: bytes, ingest_date: str) -> dict:
    sha256 = hashlib.sha256(body).hexdigest()
    s3.put_object(
        Bucket=RAW_BUCKET,
        Key=build_key(ingest_date, "data.csv.gz"),
        Body=body,
        ContentType="text/csv",
        ContentEncoding="gzip",
    )
    metadata = {
        "source_url": CSV_URL,
        "dataset_id": DATASET_ID,
        "fetched_at": datetime.now(timezone.utc).isoformat(),
        "bytes": len(body),
        "sha256": sha256,
    }
    s3.put_object(
        Bucket=RAW_BUCKET,
        Key=build_key(ingest_date, "_metadata.json"),
        Body=json.dumps(metadata, indent=2).encode(),
        ContentType="application/json",
    )
    return metadata

s3_client = boto3.client("s3")


def lambda_handler(event, context):
    ingest_date = datetime.now(timezone.utc).date().isoformat()
    metadata = upload(s3_client, fetch_csv(CSV_URL), ingest_date)
    print(json.dumps({"status": "ok", **metadata}))
    return metadata

    
if __name__ == "__main__":
    session = boto3.Session(profile_name="learnline")
    today = datetime.now(timezone.utc).date().isoformat()
    result = upload(session.client("s3"), fetch_csv(CSV_URL), today)
    print(json.dumps(result, indent=2))