from pydantic_settings import BaseSettings, SettingsConfigDict
from dotenv import load_dotenv

load_dotenv()


class SecretKeys(BaseSettings):
    COGNITO_CLIENT_ID: str = ""
    COGNITO_CLIENT_SECRET: str = ""
    REGION_NAME: str = ""
    POSTGRES_DB_URL: str = ""
    AWS_RAW_VIDEOS_BUCKET: str
    AWS_ACCESS_KEY_ID: str
    AWS_SECRET_ACCESS_KEY: str
    AWS_VIDEO_THUMBNAIL_BUCKET: str = ""

    model_config = SettingsConfigDict(
        env_file=".env",
        extra="allow",   # ✅ THIS NOW ACTUALLY WORKS
    )
