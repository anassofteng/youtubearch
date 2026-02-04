from pydantic_settings import BaseSettings  # type: ignore
from dotenv import load_dotenv  # type: ignore


load_dotenv()


class SecretKeys(BaseSettings):
    REGION_NAME: str = ""
    AWS_SQS_VIDEOS_PROCESSING: str = ""
    POSTGRES_DB_URL: str = ""

    class Config:
        env_file = ".env"
