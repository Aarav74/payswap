from pydantic import BaseModel, Field, validator
from typing import Optional, List
from datetime import datetime
from enum import Enum

class RequestType(str, Enum):
    NEED_CASH = "Need Cash"
    NEED_ONLINE_PAYMENT = "Need Online Payment"

class RequestStatus(str, Enum):
    PENDING = "pending"
    ACCEPTED = "accepted"
    COMPLETED = "completed"
    CANCELLED = "cancelled"

class TransactionStatus(str, Enum):
    PENDING = "pending"
    COMPLETED = "completed"
    FAILED = "failed"

class UserBase(BaseModel):
    email: str
    name: str
    phone: Optional[str] = None

class UserCreate(UserBase):
    password: str

class UserResponse(UserBase):
    id: str
    latitude: float
    longitude: float
    created_at: datetime
    updated_at: datetime

    class Config:
        orm_mode = True

class LocationUpdate(BaseModel):
    latitude: float = Field(..., ge=-90, le=90)
    longitude: float = Field(..., ge=-180, le=180)

class RequestCreate(BaseModel):
    amount: float = Field(..., gt=0)
    type: RequestType

    @validator('amount')
    def validate_amount(cls, v):
        if v <= 0:
            raise ValueError('Amount must be greater than 0')
        return round(v, 2)

class RequestResponse(BaseModel):
    id: str
    user_id: str
    user_name: str
    amount: float
    type: RequestType
    latitude: float
    longitude: float
    status: RequestStatus
    accepted_by: Optional[str] = None
    created_at: datetime
    updated_at: datetime
    distance_km: Optional[float] = None

    class Config:
        orm_mode = True

class RequestUpdate(BaseModel):
    status: Optional[RequestStatus] = None
    accepted_by: Optional[str] = None

class TransactionBase(BaseModel):
    request_id: str
    from_user: str
    to_user: str
    amount: float

class TransactionCreate(TransactionBase):
    pass

class TransactionResponse(TransactionBase):
    id: str
    status: TransactionStatus
    created_at: datetime

    class Config:
        orm_mode = True

class RouteRequest(BaseModel):
    start_lat: float = Field(..., ge=-90, le=90)
    start_lng: float = Field(..., ge=-180, le=180)
    end_lat: float = Field(..., ge=-90, le=90)
    end_lng: float = Field(..., ge=-180, le=180)

class Token(BaseModel):
    access_token: str
    token_type: str

class TokenData(BaseModel):
    user_id: Optional[str] = None

class LoginRequest(BaseModel):
    email: str
    password: str

class SignupRequest(UserCreate):
    pass

class ErrorResponse(BaseModel):
    detail: str

class SuccessResponse(BaseModel):
    message: str

class NearbyRequestsResponse(BaseModel):
    requests: List[RequestResponse]
    count: int

class PaginationParams(BaseModel):
    skip: int = 0
    limit: int = 100

    @validator('limit')
    def validate_limit(cls, v):
        if v > 1000:
            raise ValueError('Limit cannot exceed 1000')
        return v