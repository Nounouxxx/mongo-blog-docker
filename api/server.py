import mysql.connector
import os
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from pymongo import MongoClient

app = FastAPI()
origins = ["*"]

app.add_middleware(
    CORSMiddleware,
    allow_origins=origins,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# --- Route MySQL ---
@app.get("/users")
async def get_users():
    conn = mysql.connector.connect(
        database=os.getenv("MYSQL_DATABASE"),
        user=os.getenv("MYSQL_USER"),
        password=os.getenv("MYSQL_ROOT_PASSWORD"),
        port=3306,
        host=os.getenv("MYSQL_HOST")
    )
    cursor = conn.cursor()
    cursor.execute("SELECT * FROM utilisateur")
    records = cursor.fetchall()
    conn.close()
    return {"users": records}

# --- Route MongoDB ---
@app.get("/posts")
async def get_posts():
    client = MongoClient(
        host=os.getenv("MONGO_HOST"),
        port=27017,
        username=os.getenv("MONGO_USER"),
        password=os.getenv("MONGO_PASSWORD")
    )
    db = client["blog_db"]
    posts = list(db.posts.find({}, {"_id": 0}))
    client.close()
    return {"posts": posts}