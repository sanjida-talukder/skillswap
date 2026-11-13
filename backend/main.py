import os
import io
import smtplib
import secrets
from email.message import EmailMessage
import uuid
from pathlib import Path
from datetime import date, datetime, timedelta, timezone
import jwt
import cloudinary
from cloudinary.uploader import upload as cloudinary_upload
import bcrypt
import mysql.connector
from dotenv import load_dotenv
from fastapi import (
    FastAPI,
    HTTPException,
    UploadFile,
    File,
    Depends,
    WebSocket,
    WebSocketDisconnect,
)
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles
from pydantic import BaseModel, Field

load_dotenv()

cloudinary.config(
    cloud_name=os.getenv("CLOUDINARY_CLOUD_NAME"),
    api_key=os.getenv("CLOUDINARY_API_KEY"),
    api_secret=os.getenv("CLOUDINARY_API_SECRET"),
    secure=True
)
def upload_to_cloudinary(
    content: bytes,
    filename: str,
    content_type: str,
    folder: str
):
    if not all([
        os.getenv("CLOUDINARY_CLOUD_NAME"),
        os.getenv("CLOUDINARY_API_KEY"),
        os.getenv("CLOUDINARY_API_SECRET")
    ]):
        raise HTTPException(
            status_code=500,
            detail="Cloudinary configuration missing"
        )

    video_extensions = {
        ".mp4", ".webm", ".mov", ".m4v", ".3gp"
    }

    resource_type = (
        "video"
        if content_type.startswith("video/")
        or Path(filename).suffix.lower() in video_extensions
        else "image"
    )

    try:
        result = cloudinary_upload(
            io.BytesIO(content),
            resource_type=resource_type,
            folder=folder,
            public_id=Path(filename).stem,
            overwrite=False
        )

        return result["secure_url"]

    except Exception:
        raise HTTPException(
            status_code=502,
            detail="Cloudinary upload failed"
        )
SMTP_EMAIL = os.getenv("SMTP_EMAIL")
SMTP_APP_PASSWORD = os.getenv("SMTP_APP_PASSWORD")


def send_email_otp(receiver_email: str, otp: str):
    if not SMTP_EMAIL or not SMTP_APP_PASSWORD:
        raise HTTPException(
            status_code=500,
            detail="SMTP configuration missing"
        )

    message = EmailMessage()
    message["Subject"] = "SkillSwap Email Verification"
    message["From"] = SMTP_EMAIL
    message["To"] = receiver_email

    message.set_content(
        f"""Welcome to SkillSwap!

Your email verification OTP is: {otp}

This OTP will expire in 10 minutes.

If you did not request this code, ignore this email."""
    )

    try:
        with smtplib.SMTP_SSL("smtp.gmail.com", 465, timeout=30) as server:
                server.login(SMTP_EMAIL, SMTP_APP_PASSWORD)
                server.send_message(message)

    except Exception as exc:
        print(f"SMTP ERROR: {type(exc).__name__}: {exc}")
        raise HTTPException(
                status_code=500,
                detail="Failed to send verification email. Check backend terminal."
        )
JWT_SECRET_KEY = os.getenv("JWT_SECRET_KEY")
JWT_ALGORITHM = "HS256"
JWT_EXPIRE_MINUTES = 1440

def send_password_reset_otp(receiver_email: str, otp: str):
    if not SMTP_EMAIL or not SMTP_APP_PASSWORD:
        raise HTTPException(
            status_code=500,
            detail="SMTP configuration missing"
        )

    message = EmailMessage()
    message["Subject"] = "SkillSwap Password Reset OTP"
    message["From"] = SMTP_EMAIL
    message["To"] = receiver_email

    message.set_content(
        f"""Hello!

Your SkillSwap password reset OTP is: {otp}

This OTP will expire in 10 minutes.

If you did not request a password reset, please ignore this email."""
    )

    try:
        with smtplib.SMTP_SSL("smtp.gmail.com", 465, timeout=30) as server:
            server.login(SMTP_EMAIL, SMTP_APP_PASSWORD)
            server.send_message(message)

    except Exception as exc:
        print(f"PASSWORD RESET SMTP ERROR: {type(exc).__name__}: {exc}")
        raise HTTPException(
            status_code=500,
            detail="Failed to send password reset email"
        )
def create_access_token(user_id: str):
    if not JWT_SECRET_KEY:
        raise HTTPException(status_code=500, detail="JWT secret not configured")

    expire = datetime.now(timezone.utc) + timedelta(minutes=JWT_EXPIRE_MINUTES)

    payload = {
        "sub": user_id,
        "exp": expire
    }

    return jwt.encode(payload, JWT_SECRET_KEY, algorithm=JWT_ALGORITHM)

security = HTTPBearer()

def get_current_user(
    credentials: HTTPAuthorizationCredentials = Depends(security)
):
       try:
           payload = jwt.decode(
               credentials.credentials,
               JWT_SECRET_KEY,
               algorithms=[JWT_ALGORITHM]
           )

           user_id = payload.get("sub")

           if not user_id:
               raise HTTPException(
                   status_code=401,
                   detail="Invalid token"
               )

           return user_id

       except jwt.ExpiredSignatureError:
           raise HTTPException(status_code=401, detail="Token expired")

       except jwt.InvalidTokenError:
           raise HTTPException(status_code=401, detail="Invalid token")
class PostConnectionManager:
    def __init__(self):
        self.active_connections: dict[str, set[WebSocket]] = {}
        self.feed_connections: set[WebSocket] = set()

    async def connect(self, post_id: str, websocket: WebSocket):
        await websocket.accept()
        self.active_connections.setdefault(post_id, set()).add(websocket)

    def disconnect(self, post_id: str, websocket: WebSocket):
        connections = self.active_connections.get(post_id)

        if connections:
            connections.discard(websocket)

            if not connections:
                self.active_connections.pop(post_id, None)
    async def connect_feed(self, websocket: WebSocket):
        await websocket.accept()
        self.feed_connections.add(websocket)

    def disconnect_feed(self, websocket: WebSocket):
        self.feed_connections.discard(websocket)
    async def broadcast(self, post_id: str, message: dict):
        connections = list(
            self.active_connections.get(post_id, set())
        )

        for connection in connections:
            try:
                await connection.send_json(message)
            except Exception:
                self.disconnect(post_id, connection)
                for connection in list(self.feed_connections):
                    try:
                        await connection.send_json(message)
                    except Exception:
                        self.disconnect_feed(connection)

post_manager = PostConnectionManager()

app = FastAPI(title="SkillSwap Social API", version="2.0.0")
@app.get("/auth/me")
def auth_me(current_user_id: str = Depends(get_current_user)):
    return {
        "success": True,
        "message": "JWT authentication successful",
        "user_id": current_user_id
    }
app.add_middleware(
    CORSMiddleware,
    allow_origin_regex=r"^http://(localhost|127\.0\.0\.1)(:\d+)?$",
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

UPLOAD_DIR = Path(__file__).parent / "uploads"
UPLOAD_DIR.mkdir(parents=True, exist_ok=True)
app.mount("/uploads", StaticFiles(directory=str(UPLOAD_DIR)), name="uploads")


def db_connect():
    try:
        return mysql.connector.connect(
            host=os.getenv("DB_HOST", "localhost"),
            user=os.getenv("DB_USER", "root"),
            password=os.getenv("DB_PASSWORD", ""),
            database=os.getenv("DB_NAME", "skillswap"),
            port=int(os.getenv("DB_PORT", "3306")),
        )
    except mysql.connector.Error as exc:
        raise HTTPException(status_code=500, detail=f"Database connection failed: {exc}")


def as_iso(value):
    if isinstance(value, (datetime, date)):
        return value.isoformat()
    return value


def require_user(cursor, user_id: str):
    cursor.execute("SELECT user_id, unique_username, email, full_name, bio FROM users WHERE user_id=%s", (user_id,))
    user = cursor.fetchone()
    if not user:
        raise HTTPException(status_code=404, detail="User not found")
    return user

@app.websocket("/social/ws/posts/{post_id}")
async def post_websocket(websocket: WebSocket, post_id: str):
    token = websocket.headers.get("authorization", "")

    if not token.startswith("Bearer "):
        await websocket.close(code=1008)
        return

    token = token.replace("Bearer ", "", 1)

    try:
        payload = jwt.decode(
            token,
            JWT_SECRET_KEY,
            algorithms=[JWT_ALGORITHM]
        )

        user_id = payload.get("sub")

        if not user_id:
            await websocket.close(code=1008)
            return

        db = db_connect()
        cur = db.cursor(dictionary=True)

        try:
            require_user(cur, user_id)

            cur.execute(
                "SELECT post_id FROM social_posts WHERE post_id=%s",
                (post_id,)
            )

            if not cur.fetchone():
                await websocket.close(code=1008)
                return
        finally:
            cur.close()
            db.close()

    except Exception:
        await websocket.close(code=1008)
        return

    await post_manager.connect(post_id, websocket)

    try:
        while True:
            await websocket.receive_text()
    except WebSocketDisconnect:
        post_manager.disconnect(post_id, websocket)
    except Exception:
        post_manager.disconnect(post_id, websocket)

@app.websocket("/social/ws/feed")
async def feed_websocket(websocket: WebSocket):
    token = websocket.headers.get("authorization", "")

    if not token.startswith("Bearer "):
        await websocket.close(code=1008)
        return

    token = token.replace("Bearer ", "", 1)

    try:
        payload = jwt.decode(
            token,
            JWT_SECRET_KEY,
            algorithms=[JWT_ALGORITHM]
        )

        user_id = payload.get("sub")

        if not user_id:
            await websocket.close(code=1008)
            return

        db = db_connect()
        cur = db.cursor(dictionary=True)

        try:
            require_user(cur, user_id)
        finally:
            cur.close()
            db.close()

    except Exception as e:
        print("FEED WEBSOCKET AUTH ERROR:", repr(e))
        await websocket.close(code=1008)
        return

    await post_manager.connect_feed(websocket)

    try:
        while True:
            await websocket.receive_text()
    except WebSocketDisconnect:
        post_manager.disconnect_feed(websocket)
    except Exception:
        post_manager.disconnect_feed(websocket)
@app.get("/")
def root():
    return {"success": True, "message": "SkillSwap Social API is running"}


@app.get("/test")
def test():
    return {"success": True, "message": "FastAPI is working"}


@app.get("/database-test")
def database_test():
    db = db_connect(); cur = db.cursor()
    try:
        cur.execute("SELECT DATABASE()")
        return {"success": True, "database": cur.fetchone()[0]}
    finally:
        cur.close(); db.close()


# ---------- Existing registration/login/skills/profile compatibility ----------
class RegisterRequest(BaseModel):
    unique_username: str
    email: str
    password: str
    full_name: str = ""
    teach_skill: str = "Other"
    learn_skill: str = "Other"

@app.get("/check-username/{username}")
def check_username(username: str):
    db = db_connect(); cur = db.cursor(dictionary=True)
    try:
        cur.execute("SELECT user_id FROM users WHERE unique_username=%s", (username.strip(),))
        exists = cur.fetchone() is not None
        return {"available": not exists, "message": "Username already exists" if exists else "Username is available"}
    finally:
        cur.close(); db.close()

@app.post("/register")
def register(data: RegisterRequest):
    username, email = data.unique_username.strip(), data.email.strip().lower()
    if not username or not email or len(data.password) < 6:
        raise HTTPException(status_code=400, detail="Username, email and password (at least 6 characters) are required")
    db = db_connect(); cur = db.cursor(dictionary=True)
    try:
        cur.execute("SELECT user_id FROM users WHERE unique_username=%s OR email=%s", (username, email))
        if cur.fetchone():
            raise HTTPException(status_code=400, detail="Username or email already exists")
        user_id = str(uuid.uuid4())
        password_hash = bcrypt.hashpw(data.password.encode(), bcrypt.gensalt()).decode()
        cur.execute("INSERT INTO users (user_id, unique_username, email, password_hash, full_name) VALUES (%s,%s,%s,%s,%s)",
                    (user_id, username, email, password_hash, data.full_name.strip() or username))
        # Keep the existing skills feature working when category/table is available.
        cur.execute("SELECT category_id FROM skill_categories WHERE name='Other' LIMIT 1")
        category = cur.fetchone()
        if category:
            for skill_name, skill_type in [(data.teach_skill.strip(), "teach"), (data.learn_skill.strip(), "want_to_learn")]:
                if not skill_name: continue
                cur.execute("SELECT skill_id FROM skills WHERE LOWER(name)=LOWER(%s) LIMIT 1", (skill_name,))
                skill = cur.fetchone()
                skill_id = skill["skill_id"] if skill else str(uuid.uuid4())
                if not skill:
                    cur.execute("INSERT INTO skills (skill_id,name,description,category_id) VALUES (%s,%s,%s,%s)", (skill_id, skill_name, None, category["category_id"]))
                cur.execute("INSERT INTO user_skills (user_skill_id,user_id,skill_id,skill_type) VALUES (%s,%s,%s,%s)", (str(uuid.uuid4()), user_id, skill_id, skill_type))
        cur.execute("INSERT IGNORE INTO social_profiles (user_id, privacy) VALUES (%s,'public')", (user_id,))
        cur.execute("INSERT IGNORE INTO social_settings (user_id) VALUES (%s)", (user_id,))
        db.commit()
        return {"success": True, "message": "Registration successful", "user_id": user_id}
    except HTTPException:
        db.rollback(); raise
    except mysql.connector.Error as exc:
        db.rollback(); raise HTTPException(status_code=500, detail=f"Registration failed: {exc}")
    finally:
        cur.close(); db.close()
# ---------- Email OTP Verification ----------

class SendEmailOTPRequest(BaseModel):
    email: str


class VerifyEmailOTPRequest(BaseModel):
    email: str
    otp: str
class ForgotPasswordRequest(BaseModel):
    email: str


class ResetPasswordRequest(BaseModel):
    email: str
    otp: str
    new_password: str = Field(min_length=8)

@app.post("/send-email-otp")
def send_email_otp_api(data: SendEmailOTPRequest):
    email = data.email.strip().lower()

    db = db_connect()
    cur = db.cursor(dictionary=True)

    try:
        cur.execute(
            "SELECT user_id, is_verified FROM users WHERE email=%s",
            (email,)
        )
        user = cur.fetchone()

        if not user:
            raise HTTPException(status_code=404, detail="Account not found")

        if user["is_verified"]:
            return {"success": True, "message": "Email already verified"}

        otp = f"{secrets.randbelow(1000000):06d}"
        otp_hash = bcrypt.hashpw(
            otp.encode(),
            bcrypt.gensalt()
        ).decode()

        expires_at = datetime.now() + timedelta(minutes=10)

        cur.execute(
            "UPDATE email_verification_codes SET is_used=1 WHERE user_id=%s AND is_used=0",
            (user["user_id"],)
        )

        cur.execute(
            """INSERT INTO email_verification_codes
            (user_id, otp_hash, expires_at, is_used)
            VALUES (%s, %s, %s, 0)""",
            (user["user_id"], otp_hash, expires_at)
        )

        db.commit()

        send_email_otp(email, otp)

        return {
            "success": True,
            "message": "OTP sent to your email"
        }

    except HTTPException:
        db.rollback()
        raise
    finally:
        cur.close()
        db.close()


@app.post("/verify-email-otp")
def verify_email_otp(data: VerifyEmailOTPRequest):
    email = data.email.strip().lower()
    otp = data.otp.strip()

    if len(otp) != 6 or not otp.isdigit():
        raise HTTPException(status_code=400, detail="Invalid OTP format")

    db = db_connect()
    cur = db.cursor(dictionary=True)

    try:
        cur.execute(
            "SELECT user_id FROM users WHERE email=%s",
            (email,)
        )
        user = cur.fetchone()

        if not user:
            raise HTTPException(status_code=404, detail="Account not found")

        cur.execute(
            """SELECT id, otp_hash FROM email_verification_codes
            WHERE user_id=%s AND is_used=0 AND expires_at > NOW()
            ORDER BY id DESC LIMIT 1""",
            (user["user_id"],)
        )

        record = cur.fetchone()

        if not record or not bcrypt.checkpw(
            otp.encode(),
            record["otp_hash"].encode()
        ):
            raise HTTPException(
                status_code=400,
                detail="Invalid or expired OTP"
            )

        cur.execute(
            "UPDATE users SET is_verified=1 WHERE user_id=%s",
            (user["user_id"],)
        )

        cur.execute(
            "UPDATE email_verification_codes SET is_used=1 WHERE id=%s",
            (record["id"],)
        )

        db.commit()

        return {
            "success": True,
            "message": "Email verified successfully"
        }

    except HTTPException:
        db.rollback()
        raise
    finally:
        cur.close()
        db.close()

@app.post("/forgot-password")
def forgot_password(data: ForgotPasswordRequest):
    email = data.email.strip().lower()

    db = db_connect()
    cur = db.cursor(dictionary=True)

    try:
        cur.execute(
            "SELECT user_id, is_verified, is_active FROM users WHERE email=%s",
            (email,)
        )
        user = cur.fetchone()

        # Do not reveal whether an email address has an account.
        if not user or not user["is_verified"] or not user["is_active"]:
            return {
                "success": True,
                "message": "If the account exists, a reset OTP has been sent."
            }

        otp = f"{secrets.randbelow(1000000):06d}"
        otp_hash = bcrypt.hashpw(
            otp.encode(),
            bcrypt.gensalt()
        ).decode()

        expires_at = datetime.now() + timedelta(minutes=10)

        cur.execute(
            """UPDATE password_reset_codes
               SET is_used=1
               WHERE user_id=%s AND is_used=0""",
            (user["user_id"],)
        )

        cur.execute(
            """INSERT INTO password_reset_codes
               (user_id, otp_hash, expires_at, is_used)
               VALUES (%s, %s, %s, 0)""",
            (user["user_id"], otp_hash, expires_at)
        )

        send_password_reset_otp(email, otp)
        db.commit()

        return {
            "success": True,
            "message": "Password reset OTP sent to your email"
        }

    except HTTPException:
        db.rollback()
        raise
    except Exception:
        db.rollback()
        raise
    finally:
        cur.close()
        db.close()


@app.post("/reset-password")
def reset_password(data: ResetPasswordRequest):
    email = data.email.strip().lower()
    otp = data.otp.strip()

    if len(otp) != 6 or not otp.isdigit():
        raise HTTPException(
            status_code=400,
            detail="Invalid OTP format"
        )

    db = db_connect()
    cur = db.cursor(dictionary=True)

    try:
        cur.execute(
            "SELECT user_id FROM users WHERE email=%s",
            (email,)
        )
        user = cur.fetchone()

        if not user:
            raise HTTPException(
                status_code=400,
                detail="Invalid or expired OTP"
            )

        cur.execute(
            """SELECT id, otp_hash
               FROM password_reset_codes
               WHERE user_id=%s
               AND is_used=0
               AND expires_at > NOW()
               ORDER BY id DESC
               LIMIT 1
               FOR UPDATE""",
            (user["user_id"],)
        )

        record = cur.fetchone()

        if not record or not bcrypt.checkpw(
            otp.encode(),
            record["otp_hash"].encode()
        ):
            raise HTTPException(
                status_code=400,
                detail="Invalid or expired OTP"
            )

        new_password_hash = bcrypt.hashpw(
            data.new_password.encode(),
            bcrypt.gensalt()
        ).decode()

        cur.execute(
            "UPDATE users SET password_hash=%s WHERE user_id=%s",
            (new_password_hash, user["user_id"])
        )

        cur.execute(
            "UPDATE password_reset_codes SET is_used=1 WHERE id=%s",
            (record["id"],)
        )

        db.commit()

        return {
            "success": True,
            "message": "Password reset successfully. Please log in."
        }

    except HTTPException:
        db.rollback()
        raise
    except Exception:
        db.rollback()
        raise
    finally:
        cur.close()
        db.close()

class LoginRequest(BaseModel):
    email: str
    password: str

@app.post("/login")
def login(data: LoginRequest):
    db = db_connect()
    cur = db.cursor(dictionary=True)

    try:
        cur.execute(
            "SELECT user_id,unique_username,email,password_hash,full_name,is_active,is_verified FROM users WHERE email=%s",
            (data.email.strip().lower(),)
        )

        user = cur.fetchone()

        if not user or not bcrypt.checkpw(
            data.password.encode(),
            user["password_hash"].encode()
        ):
            raise HTTPException(status_code=401, detail="Invalid email or password")

        if not user["is_active"]:
            raise HTTPException(status_code=403, detail="Account is inactive")
        if not user["is_verified"]:
            raise HTTPException(
                status_code=403,
                detail="Please verify your email before logging in"
            )
        cur.execute(
            "INSERT IGNORE INTO social_profiles (user_id,privacy) VALUES (%s,'public')",
            (user["user_id"],)
        )

        cur.execute(
            "INSERT IGNORE INTO social_settings (user_id) VALUES (%s)",
            (user["user_id"],)
        )

        cur.execute(
            "SELECT s.name FROM user_skills us JOIN skills s ON s.skill_id=us.skill_id WHERE us.user_id=%s AND us.skill_type='teach' ORDER BY s.name",
            (user["user_id"],)
        )
        teach = ", ".join(x["name"] for x in cur.fetchall()) or "Not added yet"

        cur.execute(
            "SELECT s.name FROM user_skills us JOIN skills s ON s.skill_id=us.skill_id WHERE us.user_id=%s AND us.skill_type='want_to_learn' ORDER BY s.name",
            (user["user_id"],)
        )
        learn = ", ".join(x["name"] for x in cur.fetchall()) or "Not added yet"

        access_token = create_access_token(user["user_id"])

        return {
            "success": True,
            "message": "Login successful",
            "access_token": access_token,
            "token_type": "bearer",
            "expires_in": JWT_EXPIRE_MINUTES * 60,
            "user": {
                "user_id": user["user_id"],
                "unique_username": user["unique_username"],
                "email": user["email"],
                "full_name": user["full_name"],
                "teach_skill": teach,
                "learn_skill": learn
            }
        }

    finally:
        cur.close()
        db.close()

@app.get("/users")
def get_users():
    db = db_connect(); cur = db.cursor(dictionary=True)
    try:
        cur.execute("SELECT user_id,unique_username,email,full_name,is_active,is_verified,created_at FROM users ORDER BY created_at DESC")
        return {"success": True, "users": cur.fetchall()}
    finally:
        cur.close(); db.close()


@app.get("/skills")
def find_skills(search: str = ""):
    db = db_connect()
    cur = db.cursor(dictionary=True)

    try:
        cur.execute("""
            SELECT
                s.skill_id,
                s.name,
                s.description,
                s.category_id,
                sc.name AS category_name
            FROM skills s
            LEFT JOIN skill_categories sc
                ON sc.category_id = s.category_id
            WHERE s.name LIKE %s
            ORDER BY s.name
            LIMIT 100
        """, (f"%{search}%",))

        skills = cur.fetchall()

        for skill in skills:
            cur.execute("""
                SELECT
                    u.user_id,
                    u.unique_username,
                    us.skill_type,
                    us.level
                FROM user_skills us
                JOIN users u ON u.user_id = us.user_id
                WHERE us.skill_id = %s
                ORDER BY u.unique_username
            """, (skill["skill_id"],))

            skill["users"] = cur.fetchall()

        return {"success": True, "skills": skills}

    finally:
        cur.close()
        db.close()

@app.get("/profile/{user_id}")
def legacy_get_profile(user_id: str):
    return social_profile(user_id, user_id)

class LegacyProfileUpdate(BaseModel):
    full_name: str = ""
    bio: str = ""
    teach_skill: str = ""
    learn_skill: str = ""

@app.put("/profile/{user_id}")
def legacy_update_profile(user_id: str, data: LegacyProfileUpdate):
    db = db_connect(); cur = db.cursor(dictionary=True)
    try:
        require_user(cur, user_id)
        cur.execute("UPDATE users SET full_name=%s,bio=%s WHERE user_id=%s", (data.full_name.strip(), data.bio.strip(), user_id))
        cur.execute("SELECT category_id FROM skill_categories WHERE name='Other' LIMIT 1")
        category = cur.fetchone()
        if category:
            cur.execute("DELETE FROM user_skills WHERE user_id=%s AND skill_type IN ('teach','want_to_learn')", (user_id,))
            for names, kind in [(data.teach_skill, 'teach'), (data.learn_skill, 'want_to_learn')]:
                for name in names.split(','):
                    name = name.strip()
                    if not name: continue
                    cur.execute("SELECT skill_id FROM skills WHERE LOWER(name)=LOWER(%s) LIMIT 1", (name,)); row = cur.fetchone()
                    sid = row['skill_id'] if row else str(uuid.uuid4())
                    if not row: cur.execute("INSERT INTO skills (skill_id,name,description,category_id) VALUES (%s,%s,%s,%s)", (sid,name,None,category['category_id']))
                    cur.execute("INSERT INTO user_skills (user_skill_id,user_id,skill_id,skill_type) VALUES (%s,%s,%s,%s)", (str(uuid.uuid4()),user_id,sid,kind))
        db.commit(); return {"success": True, "message": "Profile updated"}
    except Exception:
        db.rollback(); raise
    finally:
        cur.close(); db.close()

# ---------- Social profile ----------
class SocialProfileUpdate(BaseModel):
    full_name: str = ""
    bio: str = ""
    hometown: str = ""
    present_address: str = ""
    school: str = ""
    college: str = ""
    date_of_birth: str = ""
    teach_skill: str = ""
    learn_skill: str = ""
    privacy: str = "public"
    profile_picture_url: str = ""
    latitude: float | None = None
    longitude: float | None = None
    selected_location: str = ""

@app.get("/social/profile/{target_user_id}")
def social_profile(target_user_id: str, viewer_id: str = ""):
    db = db_connect(); cur = db.cursor(dictionary=True)
    try:
        cur.execute("SELECT u.user_id,u.unique_username,u.email,u.full_name,u.bio,sp.hometown,sp.present_address,sp.school,sp.college,sp.date_of_birth,sp.profile_picture_url,sp.privacy,sp.latitude,sp.longitude,sp.selected_location FROM users u LEFT JOIN social_profiles sp ON sp.user_id=u.user_id WHERE u.user_id=%s", (target_user_id,))
        profile = cur.fetchone()
        if not profile: raise HTTPException(status_code=404, detail="Profile not found")
        cur.execute(
            "SELECT s.name FROM user_skills us "
            "JOIN skills s ON s.skill_id = us.skill_id "
            "WHERE us.user_id = %s AND us.skill_type = 'teach' "
            "ORDER BY s.name",
            (target_user_id,)
        )
        profile["teach_skill"] = ", ".join(
            row["name"] for row in cur.fetchall()
        ) or "Not added yet"

        cur.execute(
            "SELECT s.name FROM user_skills us "
            "JOIN skills s ON s.skill_id = us.skill_id "
            "WHERE us.user_id = %s AND us.skill_type = 'want_to_learn' "
            "ORDER BY s.name",
            (target_user_id,)
        )
        profile["learn_skill"] = ", ".join(
            row["name"] for row in cur.fetchall()
        ) or "Not added yet"
        cur.execute("SELECT COUNT(*) AS n FROM social_follows WHERE following_id=%s", (target_user_id,)); profile['followers_count'] = cur.fetchone()['n']
        cur.execute("SELECT COUNT(*) AS n FROM social_follows WHERE follower_id=%s", (target_user_id,)); profile['following_count'] = cur.fetchone()['n']
        is_self = viewer_id == target_user_id
        is_follower = False
        if viewer_id:
            cur.execute("SELECT 1 FROM social_follows WHERE follower_id=%s AND following_id=%s", (viewer_id,target_user_id)); is_follower = cur.fetchone() is not None
        profile['can_view_details'] = profile.get('privacy') != 'private' or is_self or is_follower
        if not profile['can_view_details']:
            for key in ['hometown','present_address','school','college','date_of_birth','latitude','longitude','selected_location']:
                profile[key] = None
        profile['date_of_birth'] = as_iso(profile.get('date_of_birth'))
        profile.pop('email', None) if not is_self else None
        return {"success": True, "profile": profile}
    finally:
        cur.close(); db.close()

@app.put("/social/profile/{user_id}")
def update_social_profile(user_id: str, data: SocialProfileUpdate):
    if data.privacy not in ('public','private'): raise HTTPException(status_code=400, detail="Privacy must be public or private")
    dob = data.date_of_birth.strip() or None
    if dob:
        try: date.fromisoformat(dob)
        except ValueError: raise HTTPException(status_code=400, detail="Date of birth must be YYYY-MM-DD")
    db = db_connect(); cur = db.cursor(dictionary=True)
    try:
        require_user(cur,user_id)
        cur.execute("UPDATE users SET full_name=%s,bio=%s WHERE user_id=%s", (data.full_name.strip(),data.bio.strip(),user_id))
        cur.execute(
                    "INSERT INTO social_profiles "
                    "(user_id,hometown,present_address,school,college,date_of_birth,profile_picture_url,privacy,latitude,longitude,selected_location) "
                    "VALUES (%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s) "
                    "ON DUPLICATE KEY UPDATE "
                    "hometown=VALUES(hometown),present_address=VALUES(present_address),"
                    "school=VALUES(school),college=VALUES(college),"
                    "date_of_birth=VALUES(date_of_birth),"
                    "profile_picture_url=VALUES(profile_picture_url),"
                    "privacy=VALUES(privacy),latitude=VALUES(latitude),longitude=VALUES(longitude),"
                    "selected_location=VALUES(selected_location)",
                    (
                        user_id, data.hometown.strip(), data.present_address.strip(),
                        data.school.strip(), data.college.strip(), dob,
                        data.profile_picture_url.strip(), data.privacy,
                        data.latitude, data.longitude, data.selected_location.strip()
                    )
                )
        cur.execute(
            "SELECT category_id FROM skill_categories WHERE name='Other' LIMIT 1"
        )
        category = cur.fetchone()

        if category:
            cur.execute(
                "DELETE FROM user_skills WHERE user_id=%s "
                "AND skill_type IN ('teach','want_to_learn')",
                (user_id,)
            )

            for names, kind in [
                (data.teach_skill, 'teach'),
                (data.learn_skill, 'want_to_learn')
            ]:
                for name in names.split(','):
                    name = name.strip()
                    if not name:
                        continue

                    cur.execute(
                        "SELECT skill_id FROM skills "
                        "WHERE LOWER(name)=LOWER(%s) LIMIT 1",
                        (name,)
                    )
                    row = cur.fetchone()

                    if row:
                        skill_id = row['skill_id']
                    else:
                        skill_id = str(uuid.uuid4())
                        cur.execute(
                            "INSERT INTO skills "
                            "(skill_id,name,description,category_id) "
                            "VALUES (%s,%s,%s,%s)",
                            (skill_id, name, None, category['category_id'])
                        )

                    cur.execute(
                        "INSERT INTO user_skills "
                        "(user_skill_id,user_id,skill_id,skill_type) "
                        "VALUES (%s,%s,%s,%s)",
                        (str(uuid.uuid4()), user_id, skill_id, kind)
                    )
        db.commit(); return {"success":True,"message":"Profile updated successfully"}
    except Exception:
        db.rollback(); raise
    finally:
        cur.close(); db.close()

@app.post("/social/upload/{user_id}")
def upload_picture(user_id: str, file: UploadFile = File(...)):
    print("UPLOAD CONTENT TYPE:", file.content_type)
    allowed_types = {
        'image/jpeg': '.jpg',
        'image/png': '.png',
        'image/webp': '.webp',
        'application/octet-stream': None,
    }

    content_type = file.content_type or ''

    if content_type not in allowed_types:
        raise HTTPException(
            status_code=400,
            detail="Only JPG, PNG or WEBP images are allowed"
        )
    content = file.file.read(5 * 1024 * 1024 + 1)
    if len(content) > 5 * 1024 * 1024: raise HTTPException(status_code=413, detail="Image must be 5 MB or smaller")
    db = db_connect(); cur = db.cursor(dictionary=True)
    try:
        require_user(cur,user_id)
        ext = allowed_types.get(content_type)

        if ext is None:
            ext = Path(file.filename or '').suffix.lower()

        if ext not in ('.jpg', '.jpeg', '.png', '.webp'):
            raise HTTPException(
                status_code=400,
                detail="Could not identify image format. Please choose a JPG, PNG or WEBP image."
            )
        filename = f"{uuid.uuid4().hex}{ext}"

        url = upload_to_cloudinary(
            content=content,
            filename=filename,
            content_type=content_type.split(";")[0].strip(),
            folder="skillswap/profile_pictures"
        )
        cur.execute("INSERT INTO social_profiles (user_id,profile_picture_url,privacy) VALUES (%s,%s,'public') ON DUPLICATE KEY UPDATE profile_picture_url=VALUES(profile_picture_url)", (user_id,url))
        db.commit(); return {"success":True,"url":url}
    except Exception:
        db.rollback(); raise
    finally:
        cur.close(); db.close()



@app.post("/social/upload-post-media/{user_id}")
def upload_post_media(user_id: str, file: UploadFile = File(...)):
    content_type = (file.content_type or "").lower().split(";")[0].strip()

    allowed_types = {
        "image/jpeg": ".jpg",
        "image/jpg": ".jpg",
        "image/png": ".png",
        "image/webp": ".webp",
        "image/heic": ".heic",
        "image/heif": ".heif",
        "video/mp4": ".mp4",
        "video/webm": ".webm",
        "video/quicktime": ".mov",
        "video/x-m4v": ".m4v",
        "video/3gpp": ".3gp",
    }

    ext = allowed_types.get(content_type)

    if not ext and content_type == "application/octet-stream":
        original_ext = Path(file.filename or "").suffix.lower()
        allowed_extensions = {
            ".jpg", ".jpeg", ".png", ".webp",
            ".heic", ".heif", ".mp4", ".webm",
            ".mov", ".m4v", ".3gp",
        }
        if original_ext in allowed_extensions:
            ext = original_ext

    if not ext:
        raise HTTPException(
            status_code=400,
            detail=f"Unsupported media type: {content_type or 'unknown'}",
        )

    content = file.file.read(500 * 1024 * 1024 + 1)
    if len(content) > 500 * 1024 * 1024:
        raise HTTPException(
            status_code=413,
            detail="Media must be 500 MB or smaller",
        )

    db = db_connect()
    cur = db.cursor(dictionary=True)
    try:
        require_user(cur, user_id)

        filename = f"{uuid.uuid4().hex}{ext}"

        url = upload_to_cloudinary(
            content=content,
            filename=filename,
            content_type=content_type,
            folder="skillswap/post_media"
        )

        db.commit()
        return {
            "success": True,
            "url": url,
            "file_type": content_type,
        }
    except Exception:
        db.rollback()
        raise
    finally:
        cur.close()
        db.close()

class AttachPostMedia(BaseModel):
    user_id: str
    file_url: str
    file_type: str



@app.post("/social/posts/{post_id}/media")
def attach_post_media(post_id: str, data: AttachPostMedia):
    db = db_connect()
    cur = db.cursor(dictionary=True)
    try:
        require_user(cur, data.user_id)

        cur.execute(
            "SELECT user_id FROM social_posts WHERE post_id=%s",
            (post_id,),
        )
        post = cur.fetchone()

        if not post:
            raise HTTPException(status_code=404, detail="Post not found")
        if post["user_id"] != data.user_id:
            raise HTTPException(status_code=403, detail="Not your post")

        if not (
            data.file_url.startswith("/uploads/")
            or data.file_url.startswith("https://res.cloudinary.com/")
        ):
            raise HTTPException(status_code=400, detail="Invalid media URL")

        file_type = data.file_type.strip().lower().split(";")[0]
        allowed_file_types = {
            "image/jpeg", "image/jpg", "image/png", "image/webp",
            "image/heic", "image/heif",
            "video/mp4", "video/webm", "video/quicktime",
            "video/x-m4v", "video/3gpp",
            "application/octet-stream",
        }

        if file_type not in allowed_file_types:
            raise HTTPException(
                status_code=400,
                detail=f"Invalid media type: {data.file_type}",
            )

        cur.execute(
            """
            INSERT INTO social_post_media
                (media_id, post_id, uploaded_by, file_url, file_type)
            VALUES (%s, %s, %s, %s, %s)
            """,
            (
                str(uuid.uuid4()),
                post_id,
                data.user_id,
                data.file_url,
                file_type,
            ),
        )
        db.commit()
        return {"success": True, "message": "Media attached to post"}
    except Exception:
        db.rollback()
        raise
    finally:
        cur.close()
        db.close()

@app.post("/social/upload-post-image/{user_id}")
def upload_post_image(user_id: str, file: UploadFile = File(...)):
    allowed_types = {
        'image/jpeg': '.jpg',
        'image/png': '.png',
        'image/webp': '.webp',
        'application/octet-stream': None,
    }

    content_type = file.content_type or ''

    if content_type not in allowed_types:
        raise HTTPException(
            status_code=400,
            detail="Only JPG, PNG or WEBP images are allowed"
        )
    content = file.file.read(5 * 1024 * 1024 + 1)
    if len(content) > 5 * 1024 * 1024:
        raise HTTPException(status_code=413, detail="Image must be 5 MB or smaller")
    db = db_connect(); cur = db.cursor(dictionary=True)
    try:
        require_user(cur, user_id)
        ext = allowed_types.get(content_type)

        if ext is None:
            ext = Path(file.filename or '').suffix.lower()

        if ext not in ('.jpg', '.jpeg', '.png', '.webp'):
            raise HTTPException(
                status_code=400,
                detail="Could not identify image format. Please choose a JPG, PNG or WEBP image."
            )
        filename = f"{uuid.uuid4().hex}{ext}"

        url = upload_to_cloudinary(
            content=content,
            filename=filename,
            content_type=content_type.split(";")[0].strip(),
            folder="skillswap/post_images"
        )

        db.commit()
        return {"success": True, "url": url}
    finally:
        cur.close(); db.close()


# ---------- Feed/posts/reactions/comments ----------
class PostCreate(BaseModel):
    user_id: str
    content: str = Field(default="", max_length=5000)
    image_url: str = ""
    privacy: str = "public"

@app.get("/social/feed")
def feed(user_id: str, limit: int = 20, offset: int = 0):
    limit = max(1,min(limit,50)); offset=max(0,offset)
    db = db_connect(); cur = db.cursor(dictionary=True)
    try:
        require_user(cur,user_id)
        cur.execute("""SELECT p.post_id,p.user_id,p.content,p.image_url,p.privacy,p.created_at,u.full_name,u.unique_username,sp.profile_picture_url,
          (SELECT COUNT(*) FROM social_post_reactions r WHERE r.post_id=p.post_id) AS reaction_count,
          (SELECT COUNT(*) FROM social_post_reactions r WHERE r.post_id=p.post_id AND r.reaction='like') AS like_count,
          (SELECT COUNT(*) FROM social_post_reactions r WHERE r.post_id=p.post_id AND r.reaction='dislike') AS dislike_count,
          (SELECT COUNT(*) FROM social_comments c WHERE c.post_id=p.post_id) AS comment_count,
          (SELECT reaction FROM social_post_reactions r2 WHERE r2.post_id=p.post_id AND r2.user_id=%s LIMIT 1) AS my_reaction
          FROM social_posts p JOIN users u ON u.user_id=p.user_id LEFT JOIN social_profiles sp ON sp.user_id=u.user_id
          WHERE p.user_id=%s
             OR (p.privacy='public' AND COALESCE(sp.privacy,'public')='public')
             OR (p.privacy='public' AND EXISTS (SELECT 1 FROM social_follows f WHERE f.follower_id=%s AND f.following_id=p.user_id))
             OR (p.privacy='followers' AND EXISTS (SELECT 1 FROM social_follows f WHERE f.follower_id=%s AND f.following_id=p.user_id))
          ORDER BY p.created_at DESC LIMIT %s OFFSET %s""", (user_id,user_id,user_id,user_id,limit,offset))
        rows = cur.fetchall()
        for row in rows:
            cur.execute(
                """
                SELECT media_id, file_url, file_type
                FROM social_post_media
                WHERE post_id = %s
                ORDER BY created_at ASC
                """,
                (row["post_id"],),
            )
            row["media"] = cur.fetchall()
            row["created_at"] = as_iso(row.get("created_at"))

        return {"success":True,"posts":rows,"limit":limit,"offset":offset}
    finally:
        cur.close(); db.close()

@app.post("/social/posts")
def create_post(data: PostCreate):
    content=data.content.strip()
    if data.privacy not in {"public", "followers", "private"}:
        raise HTTPException(status_code=400, detail="Invalid post privacy")
    if not content and not data.image_url.strip(): raise HTTPException(status_code=400,detail="Write something or attach an image")
    db=db_connect(); cur=db.cursor(dictionary=True)
    try:
        require_user(cur,data.user_id)
        post_id=str(uuid.uuid4())
        cur.execute("INSERT INTO social_posts (post_id,user_id,content,image_url,privacy) VALUES (%s,%s,%s,%s,%s)",(post_id,data.user_id,content,data.image_url.strip() or None,data.privacy))
        db.commit(); return {"success":True,"post_id":post_id,"message":"Post published"}
    except Exception: db.rollback(); raise
    finally: cur.close(); db.close()

class PostUpdate(BaseModel):
    user_id: str
    content: str = Field(default="", max_length=5000)
    privacy: str = "public"


@app.put("/social/posts/{post_id}")
def update_post(post_id: str, data: PostUpdate):
    if data.privacy not in {"public", "followers", "private"}:
        raise HTTPException(status_code=400, detail="Invalid post privacy")

    db = db_connect()
    cur = db.cursor(dictionary=True)
    try:
        require_user(cur, data.user_id)
        cur.execute(
            "SELECT user_id FROM social_posts WHERE post_id=%s",
            (post_id,)
        )
        post = cur.fetchone()

        if not post:
            raise HTTPException(status_code=404, detail="Post not found")
        if post["user_id"] != data.user_id:
            raise HTTPException(status_code=403, detail="Not your post")

        cur.execute(
            "UPDATE social_posts SET content=%s, privacy=%s WHERE post_id=%s",
            (data.content.strip(), data.privacy, post_id)
        )
        db.commit()
        return {"success": True, "message": "Post updated"}
    except Exception:
        db.rollback()
        raise
    finally:
        cur.close()
        db.close()

@app.delete("/social/posts/{post_id}")
def delete_post(post_id: str, user_id: str):
    db = db_connect()
    cur = db.cursor(dictionary=True)
    try:
        require_user(cur, user_id)
        cur.execute(
            "SELECT user_id FROM social_posts WHERE post_id=%s",
            (post_id,)
        )
        post = cur.fetchone()

        if not post:
            raise HTTPException(status_code=404, detail="Post not found")
        if post["user_id"] != user_id:
            raise HTTPException(status_code=403, detail="Not your post")

        cur.execute("DELETE FROM social_post_media WHERE post_id=%s", (post_id,))
        cur.execute("DELETE FROM social_comments WHERE post_id=%s", (post_id,))
        cur.execute("DELETE FROM social_post_reactions WHERE post_id=%s", (post_id,))
        cur.execute("DELETE FROM social_posts WHERE post_id=%s", (post_id,))
        db.commit()
        return {"success": True, "message": "Post deleted"}
    except Exception:
        db.rollback()
        raise
    finally:
        cur.close()
        db.close()

class ReactionRequest(BaseModel):
    user_id: str
    reaction: str = "like"


@app.post("/social/posts/{post_id}/react")
async def react_to_post(post_id: str, data: ReactionRequest):
    allowed = {'like', 'dislike'}

    if data.reaction not in allowed:
        raise HTTPException(
            status_code=400,
            detail="Unsupported reaction"
        )

    db = db_connect()
    cur = db.cursor(dictionary=True)

    try:
        require_user(cur, data.user_id)

        cur.execute(
            "SELECT post_id FROM social_posts WHERE post_id=%s",
            (post_id,)
        )

        if not cur.fetchone():
            raise HTTPException(status_code=404, detail="Post not found")

        cur.execute(
            """
            SELECT reaction_id, reaction
            FROM social_post_reactions
            WHERE post_id=%s AND user_id=%s
            """,
            (post_id, data.user_id)
        )

        existing = cur.fetchone()

        if existing and existing['reaction'] == data.reaction:
            cur.execute(
                "DELETE FROM social_post_reactions WHERE reaction_id=%s",
                (existing['reaction_id'],)
            )
            result = None

        elif existing:
            cur.execute(
                "UPDATE social_post_reactions SET reaction=%s WHERE reaction_id=%s",
                (data.reaction, existing['reaction_id'])
            )
            result = data.reaction

        else:
            cur.execute(
                """
                INSERT INTO social_post_reactions
                (reaction_id, post_id, user_id, reaction)
                VALUES (%s, %s, %s, %s)
                """,
                (
                    str(uuid.uuid4()),
                    post_id,
                    data.user_id,
                    data.reaction
                )
            )
            result = data.reaction

        db.commit()

        cur.execute(
            """
            SELECT COUNT(*) AS n
            FROM social_post_reactions
            WHERE post_id=%s AND reaction='like'
            """,
            (post_id,)
        )
        like_count = cur.fetchone()['n']

        cur.execute(
            """
            SELECT COUNT(*) AS n
            FROM social_post_reactions
            WHERE post_id=%s AND reaction='dislike'
            """,
            (post_id,)
        )
        dislike_count = cur.fetchone()['n']

        await post_manager.broadcast(
            post_id,
            {
                "type": "post_reaction",
                "post_id": post_id,
                "like_count": like_count,
                "dislike_count": dislike_count
            }
        )

        return {
            "success": True,
            "my_reaction": result,
            "reaction_count": like_count + dislike_count,
            "like_count": like_count,
            "dislike_count": dislike_count
        }

    except Exception:
        db.rollback()
        raise

    finally:
        cur.close()
        db.close()


class CommentCreate(BaseModel):
    user_id: str
    content: str = Field(min_length=1, max_length=2000)
    parent_comment_id: str | None = None

@app.get("/social/posts/{post_id}/comments")
def get_comments(post_id: str, current_user_id: str):
    db=db_connect(); cur=db.cursor(dictionary=True)
    try:
        require_user(cur, current_user_id)
        cur.execute(
            """
            SELECT
                c.comment_id,
                c.post_id,
                c.user_id,
                c.content,
                c.parent_comment_id,
                c.created_at,
                u.full_name,
                u.unique_username,
                sp.profile_picture_url,

                (SELECT COUNT(*)
                 FROM social_comment_reactions cr
                 WHERE cr.comment_id = c.comment_id) AS reaction_count,

                (SELECT COUNT(*)
                 FROM social_comment_reactions cr
                 WHERE cr.comment_id = c.comment_id
                 AND cr.reaction = 'like') AS like_count,

                (SELECT COUNT(*)
                 FROM social_comment_reactions cr
                 WHERE cr.comment_id = c.comment_id
                 AND cr.reaction = 'dislike') AS dislike_count,

                (SELECT reaction
                 FROM social_comment_reactions cr2
                 WHERE cr2.comment_id = c.comment_id
                 AND cr2.user_id = %s
                 LIMIT 1) AS my_reaction

            FROM social_comments c
            JOIN users u ON u.user_id = c.user_id
            LEFT JOIN social_profiles sp ON sp.user_id = u.user_id
            WHERE c.post_id = %s
            ORDER BY c.created_at ASC
            """,
            (current_user_id, post_id)
        )
        rows=cur.fetchall()
        for row in rows: row['created_at']=as_iso(row.get('created_at'))
        return {"success":True,"comments":rows}
    finally: cur.close(); db.close()


@app.post("/social/comments/{comment_id}/react")
async def react_to_comment(comment_id: str, data: ReactionRequest):
    allowed = {'like', 'dislike'}

    if data.reaction not in allowed:
        raise HTTPException(
            status_code=400,
            detail="Unsupported reaction"
        )

    db = db_connect()
    cur = db.cursor(dictionary=True)

    try:
        require_user(cur, data.user_id)

        cur.execute(
            "SELECT post_id FROM social_comments WHERE comment_id=%s",
            (comment_id,)
        )
        comment = cur.fetchone()

        if not comment:
            raise HTTPException(status_code=404, detail="Comment not found")

        post_id = comment['post_id']

        cur.execute(
            """
            SELECT reaction_id, reaction
            FROM social_comment_reactions
            WHERE comment_id=%s AND user_id=%s
            """,
            (comment_id, data.user_id)
        )
        existing = cur.fetchone()

        if existing and existing['reaction'] == data.reaction:
            cur.execute(
                "DELETE FROM social_comment_reactions WHERE reaction_id=%s",
                (existing['reaction_id'],)
            )
            result = None

        elif existing:
            cur.execute(
                "UPDATE social_comment_reactions SET reaction=%s WHERE reaction_id=%s",
                (data.reaction, existing['reaction_id'])
            )
            result = data.reaction

        else:
            cur.execute(
                """
                INSERT INTO social_comment_reactions
                (reaction_id, comment_id, user_id, reaction)
                VALUES (%s, %s, %s, %s)
                """,
                (
                    str(uuid.uuid4()),
                    comment_id,
                    data.user_id,
                    data.reaction
                )
            )
            result = data.reaction

        db.commit()

        cur.execute(
            """
            SELECT COUNT(*) AS n
            FROM social_comment_reactions
            WHERE comment_id=%s AND reaction='like'
            """,
            (comment_id,)
        )
        like_count = cur.fetchone()['n']

        cur.execute(
            """
            SELECT COUNT(*) AS n
            FROM social_comment_reactions
            WHERE comment_id=%s AND reaction='dislike'
            """,
            (comment_id,)
        )
        dislike_count = cur.fetchone()['n']

        await post_manager.broadcast(
            post_id,
            {
                "type": "comment_reaction",
                "post_id": post_id,
                "comment_id": comment_id,
                "like_count": like_count,
                "dislike_count": dislike_count
            }
        )

        return {
            "success": True,
            "my_reaction": result,
            "reaction_count": like_count + dislike_count,
            "like_count": like_count,
            "dislike_count": dislike_count
        }

    except Exception:
        db.rollback()
        raise

    finally:
        cur.close()
        db.close()


@app.delete("/social/comments/{comment_id}")
def delete_comment(comment_id: str, user_id: str):
    db = db_connect()
    cur = db.cursor(dictionary=True)
    try:
        require_user(cur, user_id)
        cur.execute(
            "SELECT user_id FROM social_comments WHERE comment_id=%s",
            (comment_id,)
        )
        comment = cur.fetchone()

        if not comment:
            raise HTTPException(status_code=404, detail="Comment not found")
        if comment["user_id"] != user_id:
            raise HTTPException(status_code=403, detail="Not your comment")

        cur.execute(
            "DELETE FROM social_comments WHERE comment_id=%s",
            (comment_id,)
        )
        db.commit()
        return {"success": True, "message": "Comment deleted"}
    except Exception:
        db.rollback()
        raise
    finally:
        cur.close()
        db.close()


@app.post("/social/posts/{post_id}/comments")
async def add_comment(post_id: str, data: CommentCreate):
    db = db_connect()
    cur = db.cursor(dictionary=True)

    try:
        require_user(cur, data.user_id)

        cur.execute(
            "SELECT post_id FROM social_posts WHERE post_id=%s",
            (post_id,)
        )

        if not cur.fetchone():
            raise HTTPException(status_code=404, detail="Post not found")

        comment_id = str(uuid.uuid4())

        cur.execute(
            """
            INSERT INTO social_comments
            (comment_id, post_id, user_id, content, parent_comment_id)
            VALUES (%s, %s, %s, %s, %s)
            """,
            (
                comment_id,
                post_id,
                data.user_id,
                data.content.strip(),
                data.parent_comment_id
            )
        )

        db.commit()

        await post_manager.broadcast(
            post_id,
            {
                "type": "new_comment",
                "post_id": post_id,
                "comment_id": comment_id
            }
        )

        return {
            "success": True,
            "message": "Comment added",
            "comment_id": comment_id
        }

    except Exception:
        db.rollback()
        raise

    finally:
        cur.close()
        db.close()


# ---------- People and follow requests ----------
@app.get("/social/people")
def people(user_id: str, search: str = ""):
    db=db_connect(); cur=db.cursor(dictionary=True)
    try:
        cur.execute("""SELECT u.user_id,u.unique_username,u.full_name,sp.profile_picture_url,COALESCE(sp.privacy,'public') AS privacy,
          (SELECT COUNT(*) FROM social_follows f WHERE f.follower_id=%s AND f.following_id=u.user_id) AS is_following,
          (SELECT status FROM social_follow_requests r WHERE r.sender_id=%s AND r.receiver_id=u.user_id ORDER BY r.created_at DESC LIMIT 1) AS request_status
          FROM users u LEFT JOIN social_profiles sp ON sp.user_id=u.user_id WHERE u.user_id<>%s AND (u.unique_username LIKE %s OR u.full_name LIKE %s) ORDER BY u.full_name LIMIT 100""",
          (user_id,user_id,user_id,f"%{search}%",f"%{search}%"))
        return {"success":True,"people":cur.fetchall()}
    finally: cur.close(); db.close()

class FollowRequestCreate(BaseModel):
    sender_id: str
    receiver_id: str



@app.post("/social/follow-requests")
def send_follow_request(data: FollowRequestCreate):
    if data.sender_id == data.receiver_id:
        raise HTTPException(
            status_code=400,
            detail="You cannot follow yourself"
        )

    db = db_connect()
    cur = db.cursor(dictionary=True)

    try:
        require_user(cur, data.sender_id)
        require_user(cur, data.receiver_id)

        cur.execute(
            "SELECT 1 FROM social_follows "
            "WHERE follower_id=%s AND following_id=%s",
            (data.sender_id, data.receiver_id)
        )
        if cur.fetchone():
            return {
                "success": True,
                "status": "following",
                "message": "Already following this user"
            }

        cur.execute(
            "SELECT request_id, status FROM social_follow_requests "
            "WHERE sender_id=%s AND receiver_id=%s "
            "ORDER BY created_at DESC LIMIT 1",
            (data.sender_id, data.receiver_id)
        )
        previous = cur.fetchone()

        if previous and previous["status"] == "pending":
            return {
                "success": True,
                "status": "pending",
                "message": "Request already pending"
            }

        if previous:
            cur.execute(
                "UPDATE social_follow_requests "
                "SET status='pending', created_at=CURRENT_TIMESTAMP "
                "WHERE request_id=%s",
                (previous["request_id"],)
            )
            request_id = previous["request_id"]
        else:
            request_id = str(uuid.uuid4())
            cur.execute(
                "INSERT INTO social_follow_requests "
                "(request_id, sender_id, receiver_id, status) "
                "VALUES (%s, %s, %s, 'pending')",
                (request_id, data.sender_id, data.receiver_id)
            )

        # Create notification only when request notifications are enabled.
        cur.execute(
            "SELECT notifications_enabled FROM social_settings "
            "WHERE user_id=%s",
            (data.receiver_id,)
        )
        general_setting = cur.fetchone()
        general_enabled = (
            general_setting is None
            or bool(general_setting["notifications_enabled"])
        )

        cur.execute(
            "SELECT requests_enabled FROM notification_preferences "
            "WHERE user_id=%s",
            (data.receiver_id,)
        )
        preference = cur.fetchone()
        requests_enabled = (
            preference is None or bool(preference["requests_enabled"])
        )

        if general_enabled and requests_enabled:
            cur.execute(
                "SELECT unique_username, full_name FROM users WHERE user_id=%s",
                (data.sender_id,)
            )
            sender = cur.fetchone()
            sender_name = (
                (sender or {}).get("full_name")
                or (sender or {}).get("unique_username")
                or "Someone"
            )

            cur.execute(
                "INSERT INTO notifications "
                "(notification_id, user_id, sender_id, notification_type, "
                "title, message, reference_id, is_read) "
                "VALUES (%s, %s, %s, 'request', %s, %s, %s, 0)",
                (
                    str(uuid.uuid4()),
                    data.receiver_id,
                    data.sender_id,
                    "New follow request",
                    f"{sender_name} sent you a follow request.",
                    request_id
                )
            )

        db.commit()
        return {
            "success": True,
            "status": "pending",
            "message": "Follow request sent"
        }

    except Exception:
        db.rollback()
        raise
    finally:
        cur.close()
        db.close()

@app.get("/social/follow-requests/{user_id}")
def incoming_requests(user_id: str):
    db=db_connect(); cur=db.cursor(dictionary=True)
    try:
        cur.execute("SELECT r.request_id,r.sender_id,r.created_at,u.full_name,u.unique_username,sp.profile_picture_url FROM social_follow_requests r JOIN users u ON u.user_id=r.sender_id LEFT JOIN social_profiles sp ON sp.user_id=u.user_id WHERE r.receiver_id=%s AND r.status='pending' ORDER BY r.created_at DESC",(user_id,))
        rows=cur.fetchall()
        for row in rows: row['created_at']=as_iso(row.get('created_at'))
        return {"success":True,"requests":rows}
    finally: cur.close(); db.close()

class FollowRequestRespond(BaseModel):
    user_id: str
    accept: bool

@app.post("/social/follow-requests/{request_id}/respond")
def respond_request(request_id: str, data: FollowRequestRespond):
    db=db_connect(); cur=db.cursor(dictionary=True)
    try:
        cur.execute("SELECT request_id,sender_id,receiver_id,status FROM social_follow_requests WHERE request_id=%s",(request_id,)); req=cur.fetchone()
        if not req: raise HTTPException(status_code=404,detail="Request not found")
        if req['receiver_id']!=data.user_id: raise HTTPException(status_code=403,detail="This request belongs to another user")
        if req['status']!='pending': raise HTTPException(status_code=400,detail="Request has already been handled")
        status='accepted' if data.accept else 'rejected'
        cur.execute("UPDATE social_follow_requests SET status=%s WHERE request_id=%s",(status,request_id))
        if data.accept: cur.execute("INSERT IGNORE INTO social_follows (follower_id,following_id) VALUES (%s,%s)",(req['sender_id'],req['receiver_id']))
        db.commit(); return {"success":True,"status":status}
    except Exception: db.rollback(); raise
    finally: cur.close(); db.close()

# ---------- Messages ----------
class MessageCreate(BaseModel):
    sender_id: str
    receiver_id: str
    content: str = Field(min_length=1,max_length=5000)

@app.get("/social/messages/{user_id}/conversations")
def conversations(user_id: str):
    db=db_connect(); cur=db.cursor(dictionary=True)
    try:
        cur.execute("""SELECT u.user_id,u.unique_username,u.full_name,sp.profile_picture_url,
          (SELECT m.content FROM social_messages m WHERE (m.sender_id=%s AND m.receiver_id=u.user_id) OR (m.sender_id=u.user_id AND m.receiver_id=%s) ORDER BY m.created_at DESC LIMIT 1) AS last_message,
          (SELECT MAX(m.created_at) FROM social_messages m WHERE (m.sender_id=%s AND m.receiver_id=u.user_id) OR (m.sender_id=u.user_id AND m.receiver_id=%s)) AS last_at
          FROM users u LEFT JOIN social_profiles sp ON sp.user_id=u.user_id WHERE u.user_id<>%s AND EXISTS (SELECT 1 FROM social_messages m WHERE (m.sender_id=%s AND m.receiver_id=u.user_id) OR (m.sender_id=u.user_id AND m.receiver_id=%s)) ORDER BY last_at DESC""",(user_id,user_id,user_id,user_id,user_id,user_id,user_id))
        rows=cur.fetchall()
        for row in rows: row['last_at']=as_iso(row.get('last_at'))
        return {"success":True,"conversations":rows}
    finally: cur.close(); db.close()

@app.get("/social/messages/{user_id}/with/{other_user_id}")
def get_messages(user_id: str, other_user_id: str):
    db=db_connect(); cur=db.cursor(dictionary=True)
    try:
        cur.execute("SELECT message_id,sender_id,receiver_id,content,created_at FROM social_messages WHERE (sender_id=%s AND receiver_id=%s) OR (sender_id=%s AND receiver_id=%s) ORDER BY created_at ASC LIMIT 500",(user_id,other_user_id,other_user_id,user_id))
        rows=cur.fetchall()
        for row in rows: row['created_at']=as_iso(row.get('created_at'))
        return {"success":True,"messages":rows}
    finally: cur.close(); db.close()


@app.post("/social/messages")
def send_message(data: MessageCreate):
    if data.sender_id == data.receiver_id:
        raise HTTPException(
            status_code=400,
            detail="You cannot message yourself"
        )

    content = data.content.strip()
    if not content:
        raise HTTPException(status_code=400, detail="Message cannot be empty")

    db = db_connect()
    cur = db.cursor(dictionary=True)

    try:
        require_user(cur, data.sender_id)
        require_user(cur, data.receiver_id)

        cur.execute(
            "SELECT allow_messages, notifications_enabled "
            "FROM social_settings WHERE user_id=%s",
            (data.receiver_id,)
        )
        setting = cur.fetchone()
        allow = setting["allow_messages"] if setting else "everyone"
        general_enabled = (
            setting is None or bool(setting["notifications_enabled"])
        )

        if allow == "none":
            raise HTTPException(
                status_code=403,
                detail="This user does not accept messages"
            )

        if allow == "followers":
            cur.execute(
                "SELECT 1 FROM social_follows "
                "WHERE follower_id=%s AND following_id=%s",
                (data.sender_id, data.receiver_id)
            )
            if not cur.fetchone():
                raise HTTPException(
                    status_code=403,
                    detail="Only followers can message this user"
                )

        message_id = str(uuid.uuid4())
        cur.execute(
            "INSERT INTO social_messages "
            "(message_id, sender_id, receiver_id, content) "
            "VALUES (%s, %s, %s, %s)",
            (message_id, data.sender_id, data.receiver_id, content)
        )

        cur.execute(
            "SELECT messages_enabled FROM notification_preferences "
            "WHERE user_id=%s",
            (data.receiver_id,)
        )
        preference = cur.fetchone()
        messages_enabled = (
            preference is None or bool(preference["messages_enabled"])
        )

        if general_enabled and messages_enabled:
            cur.execute(
                "SELECT full_name, unique_username FROM users WHERE user_id=%s",
                (data.sender_id,)
            )
            sender = cur.fetchone() or {}
            sender_name = (
                sender.get("full_name")
                or sender.get("unique_username")
                or "Someone"
            )

            cur.execute(
                "INSERT INTO notifications "
                "(notification_id, user_id, sender_id, notification_type, "
                "title, message, reference_id, is_read) "
                "VALUES (%s, %s, %s, 'message', %s, %s, %s, 0)",
                (
                    str(uuid.uuid4()),
                    data.receiver_id,
                    data.sender_id,
                    "New message",
                    f"{sender_name} sent you a message.",
                    message_id
                )
            )

        db.commit()
        return {"success": True, "message": "Message sent"}

    except Exception:
        db.rollback()
        raise
    finally:
        cur.close()
        db.close()

# ---------- Existing ratings and reviews ----------
class RatingCreateRequest(BaseModel):
    rater_id: str
    rated_user_id: str
    rating: int
    review: str = ""

@app.get("/ratings/{user_id}")
def get_ratings(user_id: str):
    db=db_connect(); cur=db.cursor(dictionary=True)
    try:
        cur.execute("SELECT r.rating_id,r.rater_id,r.rating,r.review,r.created_at,u.unique_username AS reviewer_username FROM ratings r LEFT JOIN users u ON u.user_id=r.rater_id WHERE r.rated_user_id=%s ORDER BY r.created_at DESC",(user_id,))
        rows=cur.fetchall()
        for row in rows: row['created_at']=as_iso(row.get('created_at'))
        average=round(sum(int(r['rating']) for r in rows)/len(rows),1) if rows else 0
        return {"success":True,"average_rating":average,"count":len(rows),"reviews":rows}
    finally: cur.close(); db.close()

@app.post("/ratings")
def create_rating(data: RatingCreateRequest):
    if data.rater_id==data.rated_user_id: raise HTTPException(status_code=400,detail="You cannot rate your own profile")
    if data.rating<1 or data.rating>5: raise HTTPException(status_code=400,detail="Rating must be between 1 and 5")
    db=db_connect(); cur=db.cursor(dictionary=True)
    try:
        require_user(cur,data.rater_id); require_user(cur,data.rated_user_id)
        cur.execute("INSERT INTO ratings (rating_id,rater_id,rated_user_id,post_id,rating,review) VALUES (%s,%s,%s,NULL,%s,%s)",(str(uuid.uuid4()),data.rater_id,data.rated_user_id,data.rating,data.review.strip()))
        db.commit(); return {"success":True,"message":"Review submitted successfully"}
    except Exception: db.rollback(); raise
    finally: cur.close(); db.close()


@app.get("/social/settings/{user_id}")
def get_settings(user_id: str):
    db = db_connect()
    cur = db.cursor(dictionary=True)
    try:
        require_user(cur, user_id)

        cur.execute(
            "INSERT IGNORE INTO social_settings (user_id) VALUES (%s)",
            (user_id,)
        )
        cur.execute(
            "INSERT IGNORE INTO notification_preferences (user_id) VALUES (%s)",
            (user_id,)
        )
        db.commit()

        cur.execute(
            "SELECT user_id, notifications_enabled, show_online, allow_messages "
            "FROM social_settings WHERE user_id=%s",
            (user_id,)
        )
        settings = cur.fetchone()

        cur.execute(
            "SELECT messages_enabled, comments_enabled, reactions_enabled, "
            "ratings_enabled, requests_enabled, sessions_enabled "
            "FROM notification_preferences WHERE user_id=%s",
            (user_id,)
        )
        preferences = cur.fetchone()

        settings.update(preferences or {})
        return {"success": True, "settings": settings}

    finally:
        cur.close()
        db.close()


class SettingsUpdate(BaseModel):
    notifications_enabled: bool = True
    show_online: bool = True
    allow_messages: str = "everyone"
    messages_enabled: bool | None = None
    requests_enabled: bool | None = None
    comments_enabled: bool | None = None
    reactions_enabled: bool | None = None
    ratings_enabled: bool | None = None
    sessions_enabled: bool | None = None


@app.put("/social/settings/{user_id}")
def update_settings(user_id: str, data: SettingsUpdate):
    if data.allow_messages not in ("everyone", "followers", "none"):
        raise HTTPException(
            status_code=400,
            detail="Invalid message permission"
        )

    db = db_connect()
    cur = db.cursor(dictionary=True)

    try:
        require_user(cur, user_id)

        cur.execute(
            "INSERT INTO social_settings "
            "(user_id, notifications_enabled, show_online, allow_messages) "
            "VALUES (%s, %s, %s, %s) "
            "ON DUPLICATE KEY UPDATE "
            "notifications_enabled=VALUES(notifications_enabled), "
            "show_online=VALUES(show_online), "
            "allow_messages=VALUES(allow_messages)",
            (
                user_id,
                data.notifications_enabled,
                data.show_online,
                data.allow_messages
            )
        )

        cur.execute(
            "INSERT IGNORE INTO notification_preferences (user_id) VALUES (%s)",
            (user_id,)
        )

        preference_fields = (
            "messages_enabled",
            "requests_enabled",
            "comments_enabled",
            "reactions_enabled",
            "ratings_enabled",
            "sessions_enabled",
        )

        for field in preference_fields:
            value = getattr(data, field)
            if value is not None:
                cur.execute(
                    f"UPDATE notification_preferences SET `{field}`=%s "
                    "WHERE user_id=%s",
                    (value, user_id)
                )

        db.commit()
        return {"success": True, "message": "Settings saved"}

    except Exception:
        db.rollback()
        raise
    finally:
        cur.close()
        db.close()

