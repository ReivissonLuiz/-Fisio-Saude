import os
from supabase import create_client

url = "https://nkicptibdnuygxxnoaof.supabase.co"
key = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im5raWNwdGliZG51eWd4eG5vYW9mIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc3NDQ3NjQ3MSwiZXhwIjoyMDkwMDUyNDcxfQ.q2Q_WtDt4h5jUr7wyWUedhtapkvChSNIBkJbVFzrP0M"

supabase = create_client(url, key)

response = supabase.table("usuario").select("*").eq("email", "extraordinary.rook.sxeo@hidingmail.com").execute()
print("Data in DB:")
print(response.data)
