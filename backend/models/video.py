from db.base import Base
from sqlalchemy import Column, TEXT,Integer, ForeignKey, Enum
import enum
from sqlalchemy.dialects.postgresql import UUID
import uuid

class VisibiltyStatus(enum.Enum):
    PRIVATE = "PRIVATE"
    PUBLIC = "PUBLIC"
    UNLISTED = "UNLISTED"


class ProcessingStatus(enum.Enum):
    COMPLETED = "COMPLETED"
    FAILED = "FAILED"
    IN_PROGRESS = "IN_PROGRESS"    




class Video(Base):

    __tablename__="videos"


    id=Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    title= Column(TEXT)
    description = Column(TEXT)
    user_id = Column(TEXT,ForeignKey("users.cognito_sub"))
    video_s3_key = Column(TEXT)
    visibility = Column(Enum(VisibiltyStatus),
    nullable=False, 
    default=VisibiltyStatus.PRIVATE,
    )
    is_processing = Column(Enum(ProcessingStatus),
    nullable=True,
    default=ProcessingStatus.IN_PROGRESS

    )


    def to_dict(self):
        result = {}
        for c in self.__table__.columns:
            value= getattr(self, c.name)
            if isinstance(value, enum.Enum):
                value= value.value
            result[c.name] = value
        return result    