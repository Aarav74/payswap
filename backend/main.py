from fastapi import FastAPI, Depends, HTTPException, status
from fastapi.middleware.cors import CORSMiddleware
from supabase import create_client, Client
from typing import List, Optional
import os
from pydantic import BaseModel
from datetime import datetime
import math
import requests
from dotenv import load_dotenv

load_dotenv()

app = FastAPI()

origins = [
    "http://localhost",
    "http://localhost:8000",
    "http://localhost:3000",
    "http://localhost:5000",
    "https://your-app-domain.com", 
]

app.add_middleware(
    CORSMiddleware,
    allow_origins=origins,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
    expose_headers=["Content-Disposition"],
)

supabase: Client = create_client(
    os.getenv("SUPABASE_URL"),
    os.getenv("SUPABASE_KEY")
)

GRAPHHOPPER_API_KEY = os.getenv("GRAPHHOPPER_API_KEY")

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

async def get_current_user(token: str):
    try:
        user = supabase.auth.get_user(token)
        if not user:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Invalid authentication credentials"
            )
        return user
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid authentication credentials",
            headers={"WWW-Authenticate": "Bearer"},
        )

def calculate_distance(lat1: float, lon1: float, lat2: float, lon2: float) -> float:
    R = 6371  # Earth radius in kilometers
    dlat = math.radians(lat2 - lat1)
    dlon = math.radians(lon2 - lon1)
    a = math.sin(dlat/2) * math.sin(dlat/2) + math.cos(math.radians(lat1)) * math.cos(math.radians(lat2)) * math.sin(dlon/2) * math.sin(dlon/2)
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

@app.get("/api/user/me", response_model=UserResponse)
async def get_current_user_profile(current_user = Depends(get_current_user)):
    profile = supabase.table("profiles").select("*").eq("id", current_user.id).execute()
    if not profile.data:
        raise HTTPException(status_code=404, detail="User profile not found")
    
    return profile.data[0]

@app.post("/api/user/location")
async def update_user_location(
    location: LocationUpdate,
    current_user = Depends(get_current_user)
):
    result = supabase.table("profiles").update({
        "latitude": location.latitude,
        "longitude": location.longitude,
        "updated_at": datetime.utcnow().isoformat()
    }).eq("id", current_user.id).execute()
    
    if not result.data:
        raise HTTPException(status_code=500, detail="Failed to update location")
    
    return {"message": "Location updated successfully"}

@app.get("/api/requests/nearby", response_model=List[RequestResponse])
async def get_nearby_requests(
    current_user = Depends(get_current_user),
    radius: float = 5.0  # Default radius in kilometers
):
    try:
        # Get current user's location
        user_profile = supabase.table("profiles").select("*").eq("id", current_user.id).execute()
        if not user_profile.data:
            raise HTTPException(status_code=404, detail="User profile not found")
        
        profile = user_profile.data[0]
        user_lat = profile.get("latitude", 0)
        user_lon = profile.get("longitude", 0)
        
        if user_lat == 0 or user_lon == 0:
            raise HTTPException(status_code=400, detail="User location not set")
        
        # Get all pending requests
        requests_result = supabase.table("requests").select("*").eq("status", "pending").execute()
        
        # Filter requests by distance
        nearby_requests = []
        for req in requests_result.data:
            if req["user_id"] != current_user.id:
                distance = calculate_distance(
                    user_lat, user_lon,
                    req["latitude"], req["longitude"]
                )
                if distance <= radius:
                    req_with_distance = req.copy()
                    req_with_distance['distance_km'] = distance
                    nearby_requests.append(req_with_distance)
        
        # Sort by distance (closest first)
        nearby_requests.sort(key=lambda x: x['distance_km'])
        
        return nearby_requests
        
    except Exception as e:
        raise HTTPException(
            status_code=500,
            detail=f"Error getting nearby requests: {str(e)}"
        )

@app.post("/api/requests", response_model=RequestResponse, status_code=201)
async def create_request(
    request_data: RequestCreate,
    current_user = Depends(get_current_user)
):
    try:
        print(f"Received request data: {request_data}")
        
        # Get user's current location from profiles table
        user_profile = supabase.table("profiles").select("*").eq("id", current_user.id).execute()
        if not user_profile.data:
            raise HTTPException(status_code=404, detail="User profile not found")
        
        profile = user_profile.data[0]
        
        # Validate location data
        if not all(key in profile for key in ["latitude", "longitude"]):
            raise HTTPException(
                status_code=400,
                detail="User location not set. Please update your location first."
            )
        
        # Create request payload
        request = {
            "user_id": current_user.id,
            "user_name": profile.get("name", "Unknown User"),
            "amount": float(request_data.amount),
            "type": request_data.type,
            "latitude": float(profile["latitude"]),
            "longitude": float(profile["longitude"]),
            "status": "pending",
            "created_at": datetime.utcnow().isoformat()
        }
        
        print(f"Creating request: {request}")
        
        # Insert request into database
        result = supabase.table("requests").insert(request).execute()
        
        if not result.data:
            print(f"Failed to create request. Response: {result}")
            raise HTTPException(
                status_code=500, 
                detail="Failed to create request in database"
            )
        
        print(f"Request created successfully: {result.data}")
        return result.data[0]
        
    except HTTPException:
        raise
    except Exception as e:
        print(f"Unexpected error in create_request: {str(e)}")
        raise HTTPException(
            status_code=500,
            detail=f"An unexpected error occurred: {str(e)}"
        )

@app.post("/api/requests/{request_id}/accept")
async def accept_request(
    request_id: str,
    current_user = Depends(get_current_user)
):
    # Update request status to accepted
    result = supabase.table("requests").update({
        "status": "accepted",
        "accepted_by": current_user.id
    }).eq("id", request_id).execute()
    
    if not result.data:
        raise HTTPException(status_code=404, detail="Request not found")
    
    return {"message": "Request accepted successfully"}

@app.post("/api/requests/{request_id}/complete")
async def complete_request(
    request_id: str,
    current_user = Depends(get_current_user)
):
    # Update request status to completed
    result = supabase.table("requests").update({
        "status": "completed"
    }).eq("id", request_id).execute()
    
    if not result.data:
        raise HTTPException(status_code=404, detail="Request not found")
    
    return {"message": "Request completed successfully"}

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
    uvicorn.run(app, host="0.0.0.0", port=8000)