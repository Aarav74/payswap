from supabase import create_client, Client
import os
from typing import Optional, Dict, Any, List
import logging
from datetime import datetime, timezone

# Set up logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

class Database:
    def __init__(self):
        self.supabase: Optional[Client] = None
        self.initialized = False
        
    def initialize(self):
        """Initialize the Supabase client"""
        try:
            supabase_url = os.getenv("SUPABASE_URL")
            supabase_key = os.getenv("SUPABASE_KEY")
            
            if not supabase_url or not supabase_key:
                raise ValueError("Supabase URL and Key must be provided")
                
            self.supabase = create_client(supabase_url, supabase_key)
            self.initialized = True
            logger.info("Supabase client initialized successfully")
        except Exception as e:
            logger.error(f"Failed to initialize Supabase client: {e}")
            raise

    def get_client(self) -> Client:
        """Get the Supabase client instance"""
        if not self.initialized or not self.supabase:
            self.initialize()
        return self.supabase

    async def get_user_by_id(self, user_id: str) -> Optional[Dict[str, Any]]:
        """Get user by ID"""
        try:
            result = self.get_client().table("profiles").select("*").eq("id", user_id).execute()
            if result.data and len(result.data) > 0:
                return result.data[0]
            return None
        except Exception as e:
            logger.error(f"Error getting user by ID {user_id}: {e}")
            return None

    async def update_user_location(self, user_id: str, latitude: float, longitude: float) -> bool:
        """Update user location"""
        try:
            result = self.get_client().table("profiles").update({
                "latitude": latitude,
                "longitude": longitude,
                "updated_at": datetime.now(timezone.utc).isoformat()
            }).eq("id", user_id).execute()
            
            return bool(result.data)
        except Exception as e:
            logger.error(f"Error updating user location for {user_id}: {e}")
            return False

    async def create_request(self, request_data: Dict[str, Any]) -> Optional[Dict[str, Any]]:
        """Create a new request"""
        try:
            result = self.get_client().table("requests").insert(request_data).execute()
            if result.data and len(result.data) > 0:
                return result.data[0]
            return None
        except Exception as e:
            logger.error(f"Error creating request: {e}")
            return None

    async def get_request_by_id(self, request_id: str) -> Optional[Dict[str, Any]]:
        """Get request by ID"""
        try:
            result = self.get_client().table("requests").select("*").eq("id", request_id).execute()
            if result.data and len(result.data) > 0:
                return result.data[0]
            return None
        except Exception as e:
            logger.error(f"Error getting request by ID {request_id}: {e}")
            return None

    async def update_request(self, request_id: str, update_data: Dict[str, Any]) -> bool:
        """Update request"""
        try:
            result = self.get_client().table("requests").update(update_data).eq("id", request_id).execute()
            return bool(result.data)
        except Exception as e:
            logger.error(f"Error updating request {request_id}: {e}")
            return False

    async def get_nearby_requests(self, user_lat: float, user_lon: float, radius_km: float = 5.0) -> List[Dict[str, Any]]:
        """Get nearby requests using Haversine formula"""
        try:
            # First get all pending requests
            result = self.get_client().table("requests").select("*").eq("status", "pending").execute()
            
            if not result.data:
                return []
            
            # Filter requests by distance
            nearby_requests = []
            for request in result.data:
                distance = self._calculate_distance(
                    user_lat, user_lon,
                    request["latitude"], request["longitude"]
                )
                if distance <= radius_km:
                    request_with_distance = request.copy()
                    request_with_distance["distance_km"] = distance
                    nearby_requests.append(request_with_distance)
            
            # Sort by distance (closest first)
            nearby_requests.sort(key=lambda x: x["distance_km"])
            return nearby_requests
            
        except Exception as e:
            logger.error(f"Error getting nearby requests: {e}")
            return []

    async def get_user_requests(self, user_id: str, status: Optional[str] = None) -> List[Dict[str, Any]]:
        """Get requests for a specific user"""
        try:
            query = self.get_client().table("requests").select("*").eq("user_id", user_id)
            
            if status:
                query = query.eq("status", status)
                
            result = query.order("created_at", desc=True).execute()
            return result.data if result.data else []
        except Exception as e:
            logger.error(f"Error getting requests for user {user_id}: {e}")
            return []

    async def create_transaction(self, transaction_data: Dict[str, Any]) -> Optional[Dict[str, Any]]:
        """Create a new transaction"""
        try:
            result = self.get_client().table("transactions").insert(transaction_data).execute()
            if result.data and len(result.data) > 0:
                return result.data[0]
            return None
        except Exception as e:
            logger.error(f"Error creating transaction: {e}")
            return None

    async def get_user_transactions(self, user_id: str) -> List[Dict[str, Any]]:
        """Get transactions for a specific user"""
        try:
            result = self.get_client().table("transactions").select("*").or_(
                f"from_user.eq.{user_id},to_user.eq.{user_id}"
            ).order("created_at", desc=True).execute()
            
            return result.data if result.data else []
        except Exception as e:
            logger.error(f"Error getting transactions for user {user_id}: {e}")
            return []

    async def update_transaction_status(self, transaction_id: str, status: str) -> bool:
        """Update transaction status"""
        try:
            result = self.get_client().table("transactions").update({
                "status": status,
                "updated_at": datetime.now(timezone.utc).isoformat()
            }).eq("id", transaction_id).execute()
            
            return bool(result.data)
        except Exception as e:
            logger.error(f"Error updating transaction {transaction_id}: {e}")
            return False

    def _calculate_distance(self, lat1: float, lon1: float, lat2: float, lon2: float) -> float:
        """Calculate distance between two points using Haversine formula"""
        import math
        
        R = 6371  # Earth radius in kilometers
        dlat = math.radians(lat2 - lat1)
        dlon = math.radians(lon2 - lon1)
        
        a = (math.sin(dlat/2) * math.sin(dlat/2) +
             math.cos(math.radians(lat1)) * math.cos(math.radians(lat2)) *
             math.sin(dlon/2) * math.sin(dlon/2))
        
        c = 2 * math.atan2(math.sqrt(a), math.sqrt(1-a))
        return R * c

    async def get_user_stats(self, user_id: str) -> Dict[str, Any]:
        """Get user statistics"""
        try:
            # Get completed requests count
            completed_requests = await self.get_user_requests(user_id, "completed")
            
            # Get active requests count
            active_requests = await self.get_user_requests(user_id, "pending")
            
            # Get transactions count
            transactions = await self.get_user_transactions(user_id)
            
            # Calculate total amount exchanged
            total_amount = sum(
                transaction["amount"] for transaction in transactions 
                if transaction["status"] == "completed"
            )
            
            return {
                "completed_requests": len(completed_requests),
                "active_requests": len(active_requests),
                "total_transactions": len(transactions),
                "total_amount": total_amount,
                "success_rate": len(completed_requests) / len(transactions) * 100 if transactions else 0
            }
        except Exception as e:
            logger.error(f"Error getting stats for user {user_id}: {e}")
            return {
                "completed_requests": 0,
                "active_requests": 0,
                "total_transactions": 0,
                "total_amount": 0,
                "success_rate": 0
            }

    async def search_users(self, query: str, limit: int = 10) -> List[Dict[str, Any]]:
        """Search users by name or email"""
        try:
            result = self.get_client().table("profiles").select("*").or_(
                f"name.ilike.%{query}%,email.ilike.%{query}%"
            ).limit(limit).execute()
            
            return result.data if result.data else []
        except Exception as e:
            logger.error(f"Error searching users: {e}")
            return []

    async def delete_user_data(self, user_id: str) -> bool:
        """Delete all user data (for GDPR compliance)"""
        try:
            # Delete user's requests
            self.get_client().table("requests").delete().eq("user_id", user_id).execute()
            
            # Delete user's transactions
            self.get_client().table("transactions").delete().or_(
                f"from_user.eq.{user_id},to_user.eq.{user_id}"
            ).execute()
            
            # Delete user profile
            self.get_client().table("profiles").delete().eq("id", user_id).execute()
            
            return True
        except Exception as e:
            logger.error(f"Error deleting user data for {user_id}: {e}")
            return False

# Global database instance
db = Database()