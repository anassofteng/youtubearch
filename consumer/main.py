import sys
import os

sys.path.append(
    os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "backend"))
)

from urllib.parse import unquote_plus
import json
import boto3
from secret_keys import SecretKeys
import warnings
import boto3.compat
from db.db import get_db
from models.video import Video


boto3.compat.filter_python_deprecation_warnings()

secret_keys = SecretKeys()
sqs_client = boto3.client(
    "sqs",
    region_name=secret_keys.REGION_NAME,
)
ecs_client = boto3.client(
    "ecs",
    region_name=secret_keys.REGION_NAME,
)


def poll_sqs():
    while True:
        response = sqs_client.receive_message(
            QueueUrl=secret_keys.AWS_SQS_VIDEOS_PROCESSING,
            MaxNumberOfMessages=1,
            WaitTimeSeconds=10,
        )
        for message in response.get("Messages", []):
            message_body = json.loads(message.get("Body"))

            if (
                "Service" in message_body
                and "Event" in message_body
                and message_body.get("Event") == "s3:TestEvent"
            ):
                sqs_client.delete_message(
                    QueueUrl=secret_keys.AWS_SQS_VIDEOS_PROCESSING,
                    ReceiptHandle=message["ReceiptHandle"],
                )
                continue
            if "Records" in message_body:
                s3_record = message_body["Records"][0]["s3"]
                bucket_name = s3_record["bucket"]["name"]
                raw_s3_key = s3_record["object"]["key"]
                s3_key = unquote_plus(raw_s3_key)

                print("Raw S3 key:", raw_s3_key)
                print("Decoded S3 key:", s3_key)

                db = next(get_db())
                video = db.query(Video).filter(Video.video_s3_key == s3_key).first()

                if not video:
                    print("❌ No video found for S3 key:", s3_key)
                    sqs_client.delete_message(
                        QueueUrl=secret_keys.AWS_SQS_VIDEOS_PROCESSING,
                        ReceiptHandle=message["ReceiptHandle"],
                    )
                    continue

                video_id = str(video.id)
                print("VIDEO_ID being sent to ECS:", video_id)


                response = ecs_client.run_task(
                    cluster="arn:aws:ecs:eu-north-1:960462006376:cluster/AnasTranscoderCluster",
                    launchType="FARGATE",
                    taskDefinition="arn:aws:ecs:eu-north-1:960462006376:task-definition/video-transcoder:6",
                    overrides={
                        "containerOverrides": [
                            {
                                "name": "video-transcoder",
                                "environment": [
                                    {"name": "S3_BUCKET", "value": bucket_name},
                                    {"name": "S3_KEY", "value": s3_key},
                                    {"name": "VIDEO_ID", "value": video_id},
                                ],
                            }
                        ]
                    },
                    networkConfiguration={
                        "awsvpcConfiguration": {
                            "subnets": [
                                "subnet-079a382266f74da5a",
                                "subnet-047326a7753269960",
                                "subnet-0d048af40642da44c",
                            ],
                            "assignPublicIp": "ENABLED",
                            "securityGroups": ["sg-0cf3ce7897c21e8f2"],
                        }
                    },
                )
                print(response)
                sqs_client.delete_message(
                    QueueUrl=secret_keys.AWS_SQS_VIDEOS_PROCESSING,
                    ReceiptHandle=message["ReceiptHandle"],
                )


poll_sqs()
