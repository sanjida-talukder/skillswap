from fastapi import FastAPI
import os
import mysql.connector
from dotenv import load_dotenv

load_dotenv()

app = FastAPI(title="SkillSwap API")


def get_db_connection():
    return mysql.connector.connect(
        host=os.getenv("DB_HOST"),
        user=os.getenv("DB_USER"),
        password=os.getenv("DB_PASSWORD"),
        database=os.getenv("DB_NAME"),
        port=int(os.getenv("DB_PORT", 3306))
    )


@app.get("/")
def home():
    return {
        "message": "SkillSwap Backend is running!"
    }


@app.get("/test")
def test():
    return {
        "success": True,
        "message": "FastAPI is working!"
    }


@app.get("/database-test")
def database_test():
    db = get_db_connection()
    cursor = db.cursor()

    cursor.execute("SELECT DATABASE();")
    result = cursor.fetchone()

    cursor.close()
    db.close()

    return {
        "success": True,
        "database": result[0]
    }