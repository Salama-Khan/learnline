import hashlib
import json

from handler import build_key, upload


class FakeS3:
    """Records put_object calls instead of talking to AWS."""

    def __init__(self):
        self.objects = {}

    def put_object(self, Bucket, Key, Body, **kwargs):
        self.objects[Key] = Body


def test_build_key_uses_version_partition():
    assert (
        build_key("2.0", "data.csv.gz")
        == "dfe/ks4_subject_timeseries/version=2.0/data.csv.gz"
    )

def test_upload_writes_data_and_metadata():
    # Arrange
    s3 = FakeS3()
    body = b"1000"
    version = "2.0"

    # Act
    upload(s3, body, version)

    # Assert
    assert build_key(version, "data.csv.gz") in s3.objects
    assert build_key(version, "_metadata.json") in s3.objects
    raw_metadata = s3.objects[build_key(version, "_metadata.json")]
    metadata = json.loads(raw_metadata)
    assert metadata["version"] == version
    assert metadata["sha256"] == hashlib.sha256(body).hexdigest()