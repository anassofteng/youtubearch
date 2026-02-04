from fastapi import HTTPException
import json
from models.video import ProcessingStatus, Video, VisibiltyStatus
from fastapi import APIRouter, Depends
from db.db import get_db
from db.middleware.auth_middleware import get_current_user
from sqlalchemy.orm import Session
from sqlalchemy import or_
from db.redis_db import redis_client
from uuid import UUID



router = APIRouter()

@router.get("/all")
def get_all_videos(db: Session = Depends(get_db), user=Depends(get_current_user,),):

    all_videos =( 
        db.query(Video).filter(
        Video.is_processing == ProcessingStatus.COMPLETED,
        Video.visibility == VisibiltyStatus.PUBLIC,
    ).all()
    )
    
    return all_videos


@router.get("/{video_id}")
def get_video_info(
     video_id: UUID,
    db: Session = Depends(get_db), user=Depends(get_current_user,),
    ):
    cache_key = f"video:{video_id}"
    cached_data = redis_client.get(cache_key)
    if cached_data:
        return json.loads(cached_data)
    video =( 
        db.query(Video).filter(
            Video.id == str(video_id),
        Video.is_processing == ProcessingStatus.COMPLETED,
        or_(Video.visibility == VisibiltyStatus.PUBLIC, Video.visibility == VisibiltyStatus.UNLISTED,)
    ).first()
    )

    print(video.to_dict())
    redis_client.setex(cache_key, 3600,json.dumps(video.to_dict()))
    return video.to_dict()

@router.put("/{video_id}")
def update_video_by_id(video_id: UUID, db: Session = Depends(get_db)):

    all_videos = db.query(Video.id).all()
    print(f"All video IDs in DB: {all_videos}")
    print(f"Looking for video with ID: {video_id}")

    video= db.query(Video).filter(Video.id == str(video_id)).first()

    if not video:
        raise HTTPException(404, detail="Video not found")
    video.is_processing = ProcessingStatus.COMPLETED
    db.commit()
    db.refresh(video)

    return video.to_dict()
