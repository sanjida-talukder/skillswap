
from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
import uuid
import os
import mysql.connector
import bcrypt
from dotenv import load_dotenv

load_dotenv()

app = FastAPI(title="SkillSwap API")


app.add_middleware(
    CORSMiddleware,
    allow_origin_regex=r"^http://(localhost|127\.0\.0\.1)(:\d+)?$",
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


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
    teach_skill: str
    learn_skill: str



@app.post("/register")
def register_user(user: UserCreate):
    db = get_db_connection()
    cursor = db.cursor(dictionary=True)

    try:
        username = user.unique_username.strip()
        email = user.email.strip()
        teach_skill = user.teach_skill.strip()
        learn_skill = user.learn_skill.strip()

        if not teach_skill or not learn_skill:
            raise HTTPException(
                status_code=400,
                detail="Both teach and learn skills are required"
            )

        cursor.execute("""
            SELECT user_id
            FROM users
            WHERE unique_username = %s OR email = %s
        """, (username, email))

        if cursor.fetchone():
            raise HTTPException(
                status_code=400,
                detail="Username or email already exists"
            )

        # Find the existing Other category
        cursor.execute("""
            SELECT category_id
            FROM skill_categories
            WHERE name = %s
        """, ("Other",))

        category = cursor.fetchone()

        if not category:
            raise HTTPException(
                status_code=500,
                detail="Other skill category was not found"
            )

        category_id = category["category_id"]
        user_id = str(uuid.uuid4())

        hashed_password = bcrypt.hashpw(
            user.password.encode("utf-8"),
            bcrypt.gensalt()
        ).decode("utf-8")

        cursor.execute("""
            INSERT INTO users
                (user_id, unique_username, email, password_hash, full_name)
            VALUES (%s, %s, %s, %s, %s)
        """, (
            user_id,
            username,
            email,
            hashed_password,
            user.full_name
        ))

        saved_skills = [
            (teach_skill, "teach"),
            (learn_skill, "want_to_learn")
        ]

        for skill_name, skill_type in saved_skills:
            # Reuse a skill if it already exists
            cursor.execute("""
                SELECT skill_id
                FROM skills
                WHERE LOWER(name) = LOWER(%s)
                LIMIT 1
            """, (skill_name,))

            skill = cursor.fetchone()

            if skill:
                skill_id = skill["skill_id"]
            else:
                skill_id = str(uuid.uuid4())

                cursor.execute("""
                    INSERT INTO skills
                        (skill_id, name, description, category_id)
                    VALUES (%s, %s, %s, %s)
                """, (
                    skill_id,
                    skill_name,
                    None,
                    category_id
                ))

            cursor.execute("""
                INSERT INTO user_skills
                    (user_skill_id, user_id, skill_id, skill_type)
                VALUES (%s, %s, %s, %s)
            """, (
                str(uuid.uuid4()),
                user_id,
                skill_id,
                skill_type
            ))

        db.commit()

        return {
    "success": True,
    "message": "Registration successful",
    "user_id": user_id
}
    except Exception:
        db.rollback()
        raise

    finally:
        cursor.close()
        db.close()



# ---------------- LOGIN ----------------

class LoginRequest(BaseModel):
    email: str
    password: str



@app.post("/login")
def login_user(data: LoginRequest):
    db = get_db_connection()
    cursor = db.cursor(dictionary=True)

    try:
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
        """, (data.email.strip(),))

        user = cursor.fetchone()

        if not user:
            raise HTTPException(
                status_code=401,
                detail="Invalid email or password"
            )

        password_valid = bcrypt.checkpw(
            data.password.encode("utf-8"),
            user["password_hash"].encode("utf-8")
        )

        if not password_valid:
            raise HTTPException(
                status_code=401,
                detail="Invalid email or password"
            )

        cursor.execute("""
            SELECT s.name
            FROM user_skills us
            JOIN skills s ON s.skill_id = us.skill_id
            WHERE us.user_id = %s AND us.skill_type = %s
            LIMIT 1
        """, (user["user_id"], "teach"))

        teach = cursor.fetchone()

        cursor.execute("""
            SELECT s.name
            FROM user_skills us
            JOIN skills s ON s.skill_id = us.skill_id
            WHERE us.user_id = %s AND us.skill_type = %s
            LIMIT 1
        """, (user["user_id"], "want_to_learn"))

        learn = cursor.fetchone()

        return {
            "success": True,
            "message": "Login successful",
            "user": {
                "user_id": user["user_id"],
                "unique_username": user["unique_username"],
                "email": user["email"],
                "full_name": user["full_name"],
                "is_active": user["is_active"],
                "is_verified": user["is_verified"],
                "teach_skill": teach["name"] if teach else "Not added yet",
                "learn_skill": learn["name"] if learn else "Not added yet"
            }
        }

    finally:
        cursor.close()
        db.close()

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

# ---------------- ADD / EDIT USER SKILLS ----------------

class UpdateSkillsRequest(BaseModel):
    user_id: str
    teach_skill: str
    learn_skill: str


@app.put("/user-skills")
def update_user_skills(data: UpdateSkillsRequest):
    teach_skill = data.teach_skill.strip()
    learn_skill = data.learn_skill.strip()

    if not teach_skill or not learn_skill:
        raise HTTPException(
            status_code=400,
            detail="Both skills are required"
        )

    db = get_db_connection()
    cursor = db.cursor(dictionary=True)

    try:
        cursor.execute(
            "SELECT user_id FROM users WHERE user_id = %s",
            (data.user_id.strip(),)
        )
        user = cursor.fetchone()

        if not user:
            raise HTTPException(
                status_code=404,
                detail="User not found"
            )

        cursor.execute("""
            SELECT category_id
            FROM skill_categories
            WHERE name = 'Other'
            LIMIT 1
        """)
        category = cursor.fetchone()

        if not category:
            raise HTTPException(
                status_code=500,
                detail="Other skill category not found"
            )

        for skill_name, skill_type in [
            (teach_skill, "teach"),
            (learn_skill, "want_to_learn")
        ]:
            cursor.execute("""
                SELECT skill_id
                FROM skills
                WHERE LOWER(name) = LOWER(%s)
                LIMIT 1
            """, (skill_name,))
            skill = cursor.fetchone()

            if skill:
                skill_id = skill["skill_id"]
            else:
                skill_id = str(uuid.uuid4())
                cursor.execute("""
                    INSERT INTO skills
                        (skill_id, name, description, category_id)
                    VALUES (%s, %s, %s, %s)
                """, (
                    skill_id,
                    skill_name,
                    None,
                    category["category_id"]
                ))

            cursor.execute("""
                SELECT user_skill_id
                FROM user_skills
                WHERE user_id = %s AND skill_type = %s
            """, (data.user_id.strip(), skill_type))
            existing = cursor.fetchone()

            if existing:
                cursor.execute("""
                    UPDATE user_skills
                    SET skill_id = %s
                    WHERE user_id = %s AND skill_type = %s
                """, (
                    skill_id,
                    data.user_id.strip(),
                    skill_type
                ))
            else:
                cursor.execute("""
                    INSERT INTO user_skills
                        (user_skill_id, user_id, skill_id, skill_type)
                    VALUES (%s, %s, %s, %s)
                """, (
                    str(uuid.uuid4()),
                    data.user_id.strip(),
                    skill_id,
                    skill_type
                ))

        db.commit()

        return {
            "success": True,
            "message": "Skills updated successfully",
            "teach_skill": teach_skill,
            "learn_skill": learn_skill
        }

    except Exception:
        db.rollback()
        raise

    finally:
        cursor.close()
        db.close()
