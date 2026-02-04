from fastapi import APIRouter, Cookie, Depends, HTTPException, Response
import boto3
from db.db import get_db
from db.middleware.auth_middleware import get_current_user
from models.user import User
from sqlalchemy.orm import Session

from helper.auth_helper import get_secret_hash
from pydantic_Model.auth_models import ConfirmSignupRequest, LoginRequest, SignupRequest
from secret_keys import SecretKeys

router = APIRouter()
secret_keys = SecretKeys()
COGNITO_CLIENT_ID = secret_keys.COGNITO_CLIENT_ID
COGNITO_CLIENT_SECRET = secret_keys.COGNITO_CLIENT_SECRET

cognito_client = boto3.client("cognito-idp", region_name=secret_keys.REGION_NAME)


@router.post("/signup")
def signup_user(data: SignupRequest, db: Session = Depends(get_db)):
    try:
        Secret_Hash = get_secret_hash(
            data.email, COGNITO_CLIENT_ID, COGNITO_CLIENT_SECRET
        )
        cognito_response = cognito_client.sign_up(
            ClientId=COGNITO_CLIENT_ID,
            Username=data.email,
            Password=data.password,
            SecretHash=Secret_Hash,
            UserAttributes=[
                {"Name": "name", "Value": data.name},
                {"Name": "email", "Value": data.email},
            ],
        )

        cognito_sub = cognito_response.get("UserSub")
        if not cognito_sub:
            raise Exception("Cognito did not return a valid user sub")

        new_user = User(name=data.name, email=data.email, cognito_sub=cognito_sub)
        db.add(new_user)
        db.commit()
        db.refresh(new_user)

        return {
            "message": "User signed up successfully, verify your email",
            "cognito_response": cognito_response,
        }

    except Exception as e:
        raise HTTPException(status_code=400, detail=f"Cognito signup Exception {e}")


@router.post("/login")
def login_user(data: LoginRequest, response:Response ):
    try:
        Secret_Hash = get_secret_hash(
            data.email, COGNITO_CLIENT_ID, COGNITO_CLIENT_SECRET
        )
        cognito_response = cognito_client.initiate_auth(
            ClientId=COGNITO_CLIENT_ID,
            AuthFlow="USER_PASSWORD_AUTH",
            AuthParameters={
                "USERNAME": data.email,
                "PASSWORD": data.password,
                "SECRET_HASH": Secret_Hash,
            },
        )

        

        auth_result = cognito_response.get("AuthenticationResult")
        if not auth_result:
            raise Exception("Authentication failed-Access Token not found ")
        access_token = auth_result.get("AccessToken")if auth_result else None
        refresh_token = auth_result.get("RefreshToken")if auth_result else None
        response.set_cookie(key="access_token", value=access_token, httponly=True,secure=True)
        response.set_cookie(key="refresh_token", value=refresh_token, httponly=True,secure=True)
        response.set_cookie(key="username", value=data.email, httponly=True, secure=True)

        return {"message": "Login was successful!"}
    except Exception as e:
        raise HTTPException(status_code=400, detail=f"Cognito signup Exception {e}")


@router.post("/confirm-signup")
def confirm_signup(data: ConfirmSignupRequest,):
    try:
        Secret_Hash = get_secret_hash(
            data.email, COGNITO_CLIENT_ID, COGNITO_CLIENT_SECRET
        )
        cognito_response = cognito_client.confirm_sign_up(
            ClientId=COGNITO_CLIENT_ID,
            Username=data.email,
            ConfirmationCode=data.otp,
            SecretHash=Secret_Hash,
        )

        return {"message" : "User confirmed successfully!"}
    except Exception as e:
        raise HTTPException(400, f"{e}")


@router.post("/refresh")
def refresh_token(refresh_token: str = Cookie(None),
                  user_cognito_sub = Cookie(None),
                  username: str = Cookie(None),
                  response: Response = None,
                  ):
    try:
        if not refresh_token or not user_cognito_sub:
            raise HTTPException(400, "Refresh token or user cognito sub missing")
        Secret_Hash = get_secret_hash(
            user_cognito_sub,
            username,
            COGNITO_CLIENT_ID, 
            COGNITO_CLIENT_SECRET
        )



        cognito_response = cognito_client.initiate_auth(
            ClientId=COGNITO_CLIENT_ID,
           AuthFlow="REFRESH_TOKEN_AUTH",
           AuthParameters={'REFRESH_TOKEN': refresh_token,
                           'SECRET_HASH': Secret_Hash},
            
        )

        auth_result = cognito_response.get("AuthenticationResult")

        if not auth_result:
            raise Exception("Authentication failed-Access Token not found ")
        access_token = auth_result.get("AccessToken")if auth_result else None
        
        response.set_cookie(key="access_token", value=access_token, httponly=True,secure=True)
        


        return {"message" : "Token refreshed successfully!"}
    except Exception as e:
        raise HTTPException(400, f"{e}")



@router.get("/me")
def protected_route(user=Depends(get_current_user)):
    return {"message": "You are Authenticated", "user": user}
