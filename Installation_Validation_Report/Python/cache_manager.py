#!/usr/bin/env python3
"""
Cache Manager - Knowledge base for researched applications
"""

import json
from pathlib import Path
from datetime import datetime, timedelta


class CacheManager:
    """Manage cached research results"""
    
    def __init__(self, cache_file, expiry_days=30):
        """
        Initialize cache manager
        
        Args:
            cache_file: Path to JSON cache file
            expiry_days: Number of days before cache entries expire
        """
        self.cache_file = Path(cache_file)
        self.expiry_days = expiry_days
        self.cache = self._load_cache()
    
    def _load_cache(self):
        """Load cache from disk"""
        if self.cache_file.exists():
            try:
                with open(self.cache_file, 'r', encoding='utf-8') as f:
                    return json.load(f)
            except Exception as e:
                print(f"[CACHE WARNING] Failed to load cache: {e}")
                return {}
        else:
            # Create cache directory if needed
            self.cache_file.parent.mkdir(parents=True, exist_ok=True)
            return {}
    
    def _save_cache(self):
        """Save cache to disk"""
        try:
            with open(self.cache_file, 'w', encoding='utf-8') as f:
                json.dump(self.cache, f, indent=2)
        except Exception as e:
            print(f"[CACHE ERROR] Failed to save cache: {e}")
    
    def get(self, key):
        """
        Get cached result if not expired
        
        Args:
            key: Cache key (typically application_version)
            
        Returns:
            Cached data dict or None if not found/expired
        """
        if key not in self.cache:
            return None
        
        entry = self.cache[key]
        cached_time = datetime.fromisoformat(entry.get('cached_at', '2000-01-01'))
        
        # Check if expired
        if datetime.now() - cached_time > timedelta(days=self.expiry_days):
            print(f"[CACHE EXPIRED] {key} is older than {self.expiry_days} days")
            del self.cache[key]
            self._save_cache()
            return None
        
        # Mark as cached and return
        entry['cached'] = True
        return entry
    
    def set(self, key, data):
        """
        Store data in cache
        
        Args:
            key: Cache key
            data: Data to cache (dict)
        """
        data['cached_at'] = datetime.now().isoformat()
        self.cache[key] = data
        self._save_cache()
    
    def clear_expired(self):
        """Remove all expired entries"""
        expired_keys = []
        cutoff = datetime.now() - timedelta(days=self.expiry_days)
        
        for key, entry in self.cache.items():
            cached_time = datetime.fromisoformat(entry.get('cached_at', '2000-01-01'))
            if cached_time < cutoff:
                expired_keys.append(key)
        
        for key in expired_keys:
            del self.cache[key]
        
        if expired_keys:
            self._save_cache()
            print(f"[CACHE CLEANUP] Removed {len(expired_keys)} expired entries")
    
    def clear_all(self):
        """Clear entire cache"""
        self.cache = {}
        self._save_cache()
        print("[CACHE] Cleared all entries")
    
    def list_cached(self):
        """List all cached applications"""
        return list(self.cache.keys())
    
    def get_stats(self):
        """Get cache statistics"""
        total = len(self.cache)
        
        if total == 0:
            return {"total": 0, "expired": 0, "valid": 0}
        
        cutoff = datetime.now() - timedelta(days=self.expiry_days)
        expired = 0
        
        for entry in self.cache.values():
            cached_time = datetime.fromisoformat(entry.get('cached_at', '2000-01-01'))
            if cached_time < cutoff:
                expired += 1
        
        return {
            "total": total,
            "expired": expired,
            "valid": total - expired
        }
