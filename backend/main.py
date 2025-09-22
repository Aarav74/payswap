from fastapi import FastAPI, Depends, HTTPException, status, Header
from fastapi.middleware.cors import CORSMiddleware
from numpy import sin
from supabase import create_client, Client
from typing import List, Optional, Dict, Any
import os
from pydantic import BaseModel
from datetime import datetime, timedelta
import math
import requests
import json
from dotenv import load_dotenv
import traceback
import logging

# Set up logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

load_dotenv()

app = FastAPI()

# Allow all origins for development
origins = [
    "*",  # Allow all origins for development
]

app.add_middleware(
    CORSMiddleware,
    allow_origins=origins,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
    expose_headers=["*"],
)

supabase: Client = create_client(
    os.getenv("SUPABASE_URL"),
    os.getenv("SUPABASE_KEY")
)

GRAPHHOPPER_API_KEY = os.getenv("GRAPHHOPPER_API_KEY")

# Models
class LocationUpdate(BaseModel):
    latitude: float
    longitude: float

class RequestCreate(BaseModel):
    amount: float
    type: str

class RequestResponse(BaseModel):
    id: str
    user_id: str
    user_name: str
    amount: float
    type: str
    latitude: float
    longitude: float
    created_at: datetime
    status: str
    distance_km: Optional[float] = None

    class Config:
        orm_mode = True

class UserResponse(BaseModel):
    id: str
    email: str
    name: str
    latitude: float
    longitude: float

    class Config:
        orm_mode = True

# Authentication dependency
async def get_current_user(authorization: Optional[str] = Header(None)):
    if not authorization:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Authorization header required"
        )
    
    try:
        # Remove "Bearer " prefix if present
        if authorization.startswith("Bearer "):
            token = authorization[7:]
        else:
            token = authorization
        
        user = supabase.auth.get_user(token)
        if not user or not user.user:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Invalid authentication credentials"
            )
        return user.user
    except Exception as e:
        logger.error(f"Authentication error: {e}")
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid authentication credentials",
            headers={"WWW-Authenticate": "Bearer"},
        )

# Helper functions
def calculate_distance(lat1: float, lon1: float, lat2: float, lon2: float) -> float:
    R = 6371 
    dlat = math.radians(lat2 - lat1)
    dlon = math.radians(lon2 - lon1)
    a = math.sin(dlat/2) * math.sin(dlat/2) + math.cos(math.radians(lat1)) * math.cos(math.radians(lat2)) * math.sin(dlon/2) * sin(dlon/2)
    c = 2 * math.atan2(math.sqrt(a), math.sqrt(1-a))
    return R * c

def get_address_from_coordinates(lat: float, lng: float) -> str:
    try:
        response = requests.get(
            f"https://graphhopper.com/api/1/geocode?point={lat},{lng}&reverse=true&key={GRAPHHOPPER_API_KEY}"
        )
        if response.status_code == 200:
            data = response.json()
            if data.get('hits') and len(data['hits']) > 0:
                hit = data['hits'][0]
                address = hit.get('name', '')
                if hit.get('city'):
                    address += f", {hit['city']}"
                if hit.get('country'):
                    address += f", {hit['country']}"
                return address
        return f"Location: {lat}, {lng}"
    except Exception:
        return f"Location: {lat}, {lng}"

# REST Endpoints
@app.get("/")
async def root():
    return {"message": "Cash Exchange API", "version": "2.0.0", "realtime_method": "http_polling"}

@app.get("/health")
async def health_check():
    """Health check endpoint for monitoring"""
    return {
        "status": "healthy",
        "timestamp": datetime.utcnow().isoformat(),
        "version": "2.0.0"
    }

@app.get("/api/user/me", response_model=UserResponse)
async def get_current_user_profile(current_user = Depends(get_current_user)):
    try:
        profile = supabase.table("profiles").select("*").eq("id", current_user.id).execute()
        if not profile.data:
            raise HTTPException(status_code=404, detail="User profile not found")
        
        return profile.data[0]
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error getting user profile: {e}")
        raise HTTPException(status_code=500, detail="Internal server error")

@app.post("/api/user/location")
async def update_user_location(
    location: LocationUpdate,
    current_user = Depends(get_current_user)
):
    try:
        logger.info(f"Updating location for user {current_user.id} to {location.latitude}, {location.longitude}")
        
        # Validate coordinates
        if not (-90 <= location.latitude <= 90) or not (-180 <= location.longitude <= 180):
            raise HTTPException(
                status_code=400, 
                detail="Invalid coordinates. Latitude must be between -90 and 90, longitude between -180 and 180."
            )
        
        result = supabase.table("profiles").update({
            "latitude": location.latitude,
            "longitude": location.longitude,
            "updated_at": datetime.utcnow().isoformat()
        }).eq("id", current_user.id).execute()
        
        if not result.data:
            logger.error(f"Failed to update location for user {current_user.id}")
            raise HTTPException(status_code=500, detail="Failed to update location")
        
        logger.info(f"Location updated successfully for user {current_user.id}")
        return {"message": "Location updated successfully"}
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error updating location: {e}")
        raise HTTPException(status_code=500, detail="Internal server error")

@app.get("/api/requests/nearby", response_model=List[RequestResponse])
async def get_nearby_requests(
    current_user = Depends(get_current_user),
    radius: float = 5.0,
    since: Optional[str] = None  # ISO timestamp for incremental updates
):
    try:
        logger.info(f"Getting nearby requests for user {current_user.id} within {radius}km")
        
        user_profile = supabase.table("profiles").select("*").eq("id", current_user.id).execute()
        if not user_profile.data:
            raise HTTPException(status_code=404, detail="User profile not found")
        
        profile = user_profile.data[0]
        user_lat = profile.get("latitude", 0)
        user_lon = profile.get("longitude", 0)
        
        if user_lat == 0 or user_lon == 0:
            raise HTTPException(
                status_code=400, 
                detail="User location not set. Please enable location services and update your location."
            )
        
        # Build query - only get pending requests, exclude own requests
        query = supabase.table("requests").select("*").eq("status", "pending").neq("user_id", current_user.id)
        
        # Add time filter for incremental updates
        if since:
            try:
                since_datetime = datetime.fromisoformat(since.replace('Z', '+00:00'))
                query = query.gte("created_at", since_datetime.isoformat())
            except ValueError:
                # Invalid timestamp format, ignore the filter
                pass
        
        requests_result = query.execute()
        
        nearby_requests = []
        for req in requests_result.data:
            distance = calculate_distance(
                user_lat, user_lon,
                req["latitude"], req["longitude"]
            )
            if distance <= radius:
                req_with_distance = req.copy()
                req_with_distance['distance_km'] = distance
                nearby_requests.append(req_with_distance)
        
        nearby_requests.sort(key=lambda x: x['distance_km'])
        logger.info(f"Found {len(nearby_requests)} nearby requests for user {current_user.id}")
        return nearby_requests
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error getting nearby requests: {e}")
        raise HTTPException(status_code=500, detail="Internal server error")

@app.get("/api/requests/recent", response_model=List[RequestResponse])
async def get_recent_requests(
    current_user = Depends(get_current_user),
    minutes: int = 5  # Get requests from last N minutes
):
    """Get recently created requests for polling updates"""
    try:
        since_time = datetime.utcnow() - timedelta(minutes=minutes)
        
        user_profile = supabase.table("profiles").select("*").eq("id", current_user.id).execute()
        if not user_profile.data:
            raise HTTPException(status_code=404, detail="User profile not found")
        
        profile = user_profile.data[0]
        user_lat = profile.get("latitude", 0)
        user_lon = profile.get("longitude", 0)
        
        if user_lat == 0 or user_lon == 0:
            return []  # Return empty if no location
        
        # Get recent requests
        requests_result = supabase.table("requests").select("*")\
            .eq("status", "pending")\
            .neq("user_id", current_user.id)\
            .gte("created_at", since_time.isoformat())\
            .execute()
        
        nearby_requests = []
        for req in requests_result.data:
            distance = calculate_distance(
                user_lat, user_lon,
                req["latitude"], req["longitude"]
            )
            if distance <= 5.0:  # 5km radius
                req_with_distance = req.copy()
                req_with_distance['distance_km'] = distance
                nearby_requests.append(req_with_distance)
        
        nearby_requests.sort(key=lambda x: x['distance_km'])
        return nearby_requests
        
    except Exception as e:
        logger.error(f"Error getting recent requests: {e}")
        return []

@app.post("/api/requests", response_model=RequestResponse, status_code=201)
async def create_request(
    request_data: RequestCreate,
    current_user = Depends(get_current_user)
):
    try:
        logger.info(f"Received request data: {request_data} from user {current_user.id}")
        
        # Validate amount
        if request_data.amount <= 0:
            raise HTTPException(
                status_code=400,
                detail="Amount must be greater than 0"
            )
        
        # Validate type
        if request_data.type not in ['Need Cash', 'Need Online Payment']:
            raise HTTPException(
                status_code=400,
                detail="Invalid request type. Must be 'Need Cash' or 'Need Online Payment'"
            )
        
        # Get user profile with better error handling
        user_profile = supabase.table("profiles").select("*").eq("id", current_user.id).execute()
        if not user_profile.data:
            logger.error(f"No profile found for user {current_user.id}")
            raise HTTPException(
                status_code=404, 
                detail="User profile not found. Please complete your profile setup."
            )
        
        profile = user_profile.data[0]
        logger.info(f"User profile: {profile}")
        
        # Check for required location data with better validation
        latitude = profile.get("latitude")
        longitude = profile.get("longitude")
        
        if latitude is None or longitude is None:
            logger.error(f"Location data missing: lat={latitude}, lng={longitude}")
            raise HTTPException(
                status_code=400,
                detail="Location not set. Please enable location services and try again."
            )
        
        # Convert to float and validate
        try:
            lat_float = float(latitude)
            lng_float = float(longitude)
            
            # Validate coordinates
            if not (-90 <= lat_float <= 90) or not (-180 <= lng_float <= 180):
                raise ValueError("Invalid coordinate range")
                
            if lat_float == 0 and lng_float == 0:
                raise ValueError("Zero coordinates")
        except (ValueError, TypeError) as e:
            logger.error(f"Invalid location data: lat={latitude}, lng={longitude}, error={e}")
            raise HTTPException(
                status_code=400,
                detail="Invalid location data. Please update your location and try again."
            )
        
        request = {
            "user_id": current_user.id,
            "user_name": profile.get("name", "Unknown User"),
            "amount": float(request_data.amount),
            "type": api_type,  # Use the mapped type
            "latitude": lat_float,
            "longitude": lng_float,
            "status": "pending",
            "created_at": datetime.utcnow().isoformat()
        }
        
        logger.info(f"Creating request: {request}")
        
        result = supabase.table("requests").insert(request).execute()
        
        if not result.data:
            logger.error(f"Failed to create request. Supabase response: {result}")
            raise HTTPException(
                status_code=500, 
                detail="Failed to create request in database. Please try again."
            )
        
        logger.info(f"Request created successfully: {result.data}")
        
        # No WebSocket broadcast needed - clients will poll for updates
        return result.data[0]
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Unexpected error in create_request: {str(e)}")
        traceback.print_exc()
        raise HTTPException(
            status_code=500,
            detail="An unexpected error occurred while creating the request. Please try again."
        )

@app.post("/api/requests/{request_id}/accept")
async def accept_request(
    request_id: str,
    current_user = Depends(get_current_user)
):
    try:
        result = supabase.table("requests").update({
            "status": "accepted",
            "accepted_by": current_user.id,
            "updated_at": datetime.utcnow().isoformat()
        }).eq("id", request_id).execute()
        
        if not result.data:
            raise HTTPException(status_code=404, detail="Request not found")
        
        # No WebSocket broadcast needed
        return {"message": "Request accepted successfully", "data": result.data[0]}
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error accepting request: {e}")
        raise HTTPException(status_code=500, detail="Internal server error")

@app.post("/api/requests/{request_id}/complete")
async def complete_request(
    request_id: str,
    current_user = Depends(get_current_user)
):
    try:
        result = supabase.table("requests").update({
            "status": "completed",
            "updated_at": datetime.utcnow().isoformat()
        }).eq("id", request_id).execute()
        
        if not result.data:
            raise HTTPException(status_code=404, detail="Request not found")
        
        # No WebSocket broadcast needed
        return {"message": "Request completed successfully", "data": result.data[0]}
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error completing request: {e}")
        raise HTTPException(status_code=500, detail="Internal server error")

@app.get("/api/route")
async def get_route(
    start_lat: float,
    start_lng: float,
    end_lat: float,
    end_lng: float,
    current_user = Depends(get_current_user)
):
    try:
        response = requests.get(
            f"https://graphhopper.com/api/1/route?"
            f"point={start_lat},{start_lng}&"
            f"point={end_lat},{end_lng}&"
            f"vehicle=foot&"
            f"key={GRAPHHOPPER_API_KEY}"
        )
        
        if response.status_code == 200:
            return response.json()
        else:
            raise HTTPException(
                status_code=response.status_code,
                detail="Failed to get route from GraphHopper"
            )
    except Exception as e:
        raise HTTPException(
            status_code=500,
            detail=f"Error getting route: {str(e)}"
        )

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(
        app, 
        host="0.0.0.0", 
        port=8000,
        timeout_keep_alive=30,
    )