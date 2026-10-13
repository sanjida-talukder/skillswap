from fastapi import FastAPI, HTTPException
from pydantic import BaseModel
import os
import mysql.connector
import bcrypt
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


# ---------------- HOME ----------------

@app.get("/")
def home():
    return {"message": "SkillSwap Backend is running!"}


# ---------------- TEST ----------------

@app.get("/test")
def test():
    return {"success": True, "message": "FastAPI is working!"}


# ---------------- DATABASE TEST ----------------

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


# ---------------- GET USERS ----------------

@app.get("/users")
def get_users():
    db = get_db_connection()
    cursor = db.cursor(dictionary=True)

    cursor.execute("""
        SELECT
            user_id,
            unique_username,
            email,
            full_name,
            is_active,
            is_verified,
            created_at
        FROM users
        ORDER BY created_at DESC
    """)

    users = cursor.fetchall()

    cursor.close()
    db.close()

    return {
        "success": True,
        "count": len(users),
        "users": users
    }


# ---------------- REGISTER ----------------

class UserCreate(BaseModel):
    unique_username: str
    email: str
    password: str
    full_name: str | None = None


@app.post("/register")
def register_user(user: UserCreate):

    db = get_db_connection()
    cursor = db.cursor(dictionary=True)

    # Check username/email already exists
    cursor.execute("""
        SELECT user_id
        FROM users
        WHERE unique_username = %s OR email = %s
    """, (user.unique_username, user.email))

    existing_user = cursor.fetchone()

    if existing_user:
        cursor.close()
        db.close()

        raise HTTPException(
            status_code=400,
            detail="Username or email already exists"
        )

    # Hash password
    hashed_password = bcrypt.hashpw(
        user.password.encode("utf-8"),
        bcrypt.gensalt()
    ).decode("utf-8")

    # Insert user
    cursor.execute("""
        INSERT INTO users
        (
            user_id,
            unique_username,
            email,
            password_hash,
            full_name
        )
        VALUES
        (
            UUID(),
            %s,
            %s,
            %s,
            %s
        )
    """, (
        user.unique_username,
        user.email,
        hashed_password,
        user.full_name
    ))

    db.commit()

    cursor.close()
    db.close()

    return {
        "success": True,
        "message": "Registration successful"
    }

# ---------------- LOGIN ----------------

class LoginRequest(BaseModel):
    email: str
    password: str


@app.post("/login")
def login_user(data: LoginRequest):

    db = get_db_connection()
    cursor = db.cursor(dictionary=True)

    cursor.execute("""
        SELECT
            user_id,
            unique_username,
            email,
            password_hash,
            full_name,
            is_active,
            is_verified
        FROM users
        WHERE email = %s
    """, (data.email,))

    user = cursor.fetchone()

    if not user:
        cursor.close()
        db.close()
        raise HTTPException(
            status_code=401,
            detail="Invalid email or password"
        )

    # Verify password
    password_valid = bcrypt.checkpw(
        data.password.encode("utf-8"),
        user["password_hash"].encode("utf-8")
    )

    if not password_valid:
        cursor.close()
        db.close()
        raise HTTPException(
            status_code=401,
            detail="Invalid email or password"
        )

    cursor.close()
    db.close()

    return {
        "success": True,
        "message": "Login successful",
        "user": {
            "user_id": user["user_id"],
            "unique_username": user["unique_username"],
            "email": user["email"],
            "full_name": user["full_name"],
            "is_active": user["is_active"],
            "is_verified": user["is_verified"]
        }
    }
# ---------------- FIND A SKILL ----------------

@app.get("/skills")
def find_skills(search: str = ""):
    db = get_db_connection()
    cursor = db.cursor(dictionary=True)

    try:
        cursor.execute("""
            SELECT
                s.skill_id,
                s.name,
                s.description,
                s.category_id,
                sc.name AS category_name
            FROM skills s
            LEFT JOIN skill_categories sc
                ON s.category_id = sc.category_id
            WHERE s.name LIKE %s
            ORDER BY s.name ASC
        """, (f"%{search}%",))

        skills = cursor.fetchall()

        return {
            "success": True,
            "count": len(skills),
            "skills": skills
        }
    finally:
        cursor.close()
        db.close()
