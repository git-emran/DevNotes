# FastAPI Cheatsheet — Senior Developer Interview

 ## 1. Core Concepts & Why FastAPI

 - Built on **Starlette** (ASGI web toolkit) + **Pydantic** (data validation via Python type hints).
- **ASGI** (Asynchronous Server Gateway Interface), not WSGI — enables native async, WebSockets, HTTP/2.
- Automatic **OpenAPI/Swagger** docs generated from type hints (`/docs`, `/redoc`).
- Type hints double as runtime validation *and* editor autocomplete *and* documentation — a key selling point to articulate.

 ```python
from fastapi import FastAPI
app = FastAPI()

@app.get("/items/{item_id}")
async def read_item(item_id: int, q: str | None = None):
    return {"item_id": item_id, "q": q}
```

 ## 2. Pydantic Models (v2 — know the differences from v1)

 ```python
from pydantic import BaseModel, Field, field_validator, ConfigDict

class UserCreate(BaseModel):
    model_config = ConfigDict(str_strip_whitespace=True)  # v2 config style

    name: str = Field(min_length=1, max_length=50)
    age: int = Field(gt=0, le=150)
    email: str

    @field_validator("email")
    @classmethod
    def validate_email(cls, v):
        if "@" not in v:
            raise ValueError("invalid email")
        return v.lower()

# Pydantic v1 -> v2 key changes (frequently asked)
# - `@validator` -> `@field_validator`
# - `class Config` -> `model_config = ConfigDict(...)`
# - `.dict()` -> `.model_dump()`
# - `.json()` -> `.model_dump_json()`
# - `parse_obj()` -> `model_validate()`
# - Core validation logic rewritten in Rust (pydantic-core) — major perf gain

# Nested & response models
class UserOut(BaseModel):
    id: int
    name: str
    # exclude sensitive fields like password by using a separate output model

@app.post("/users", response_model=UserOut)
async def create_user(user: UserCreate):
    ...
```

 ## 3. Dependency Injection (a favorite senior-level topic)

 ```python
from fastapi import Depends, HTTPException, status

# Simple dependency
def get_query_param(q: str | None = None):
    return q

# Class-based dependency (good for shared config/pagination)
class Pagination:
    def __init__(self, skip: int = 0, limit: int = 100):
        self.skip = skip
        self.limit = limit

@app.get("/items")
async def list_items(pagination: Pagination = Depends()):
    ...

# Dependency with sub-dependencies (auth pattern)
async def get_current_user(token: str = Depends(oauth2_scheme)):
    user = decode_token(token)
    if not user:
        raise HTTPException(status.HTTP_401_UNAUTHORIZED)
    return user

async def get_current_active_user(user=Depends(get_current_user)):
    if not user.is_active:
        raise HTTPException(400, "Inactive user")
    return user

@app.get("/me")
async def read_me(user=Depends(get_current_active_user)):
    return user

# yield dependencies — for setup/teardown (DB sessions, etc.)
async def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()

# Dependency caching — same dependency called multiple times in one request
# is only executed ONCE by default (cached per-request), unless use_cache=False
Depends(get_db, use_cache=False)

# Dependency overrides — critical for testing
app.dependency_overrides[get_db] = get_test_db
```

 ## 4. Async vs Sync Route Handlers (a very common interview question)

 ```python
# `async def` — runs on the event loop; use for I/O-bound async operations
@app.get("/async-route")
async def async_route():
    result = await some_async_db_call()
    return result

# `def` (sync) — FastAPI runs it in a separate thread pool automatically,
# so it doesn't block the event loop
@app.get("/sync-route")
def sync_route():
    result = blocking_db_call()   # fine, runs in threadpool
    return result

# THE TRAP: calling blocking code inside an `async def` route
@app.get("/bad")
async def bad_route():
    time.sleep(5)   # BLOCKS the entire event loop — freezes ALL concurrent requests
    return {}

# Fix: either make it a sync `def` route, or offload to a thread
from fastapi.concurrency import run_in_threadpool
result = await run_in_threadpool(blocking_call)
```

 ## 5. Request/Response Handling

 ```python
from fastapi import Query, Path, Body, Header, Cookie, File, UploadFile

@app.get("/items/{item_id}")
async def read(
    item_id: int = Path(..., gt=0),
    q: str = Query(default=None, max_length=50),
    x_token: str = Header(...),
):
    ...

# Request body
@app.post("/items")
async def create(item: ItemModel = Body(...)):
    ...

# File upload
@app.post("/upload")
async def upload(file: UploadFile = File(...)):
    contents = await file.read()

# Custom status codes & responses
from fastapi.responses import JSONResponse, StreamingResponse
@app.get("/custom")
async def custom():
    return JSONResponse(status_code=201, content={"ok": True})

# Streaming response (large files/data)
@app.get("/stream")
async def stream():
    def gen():
        for chunk in big_data:
            yield chunk
    return StreamingResponse(gen(), media_type="text/csv")
```

 ## 6. Middleware & Background Tasks

 ```python
from fastapi import BackgroundTasks

@app.post("/send-notification")
async def notify(email: str, background_tasks: BackgroundTasks):
    background_tasks.add_task(send_email, email)   # runs AFTER response is sent
    return {"message": "queued"}

# Middleware
@app.middleware("http")
async def add_process_time_header(request, call_next):
    start = time.time()
    response = await call_next(request)
    response.headers["X-Process-Time"] = str(time.time() - start)
    return response

# NOTE: BackgroundTasks run in-process, tied to the request lifecycle.
# For heavier/long-running/distributed work, use Celery, RQ, or Arq instead —
# this distinction is a common senior-level "when would you NOT use this" question.
```

 ## 7. Database Patterns (SQLAlchemy 2.0 async is the current standard)

 ```python
from sqlalchemy.ext.asyncio import create_async_engine, AsyncSession
from sqlalchemy.orm import sessionmaker

engine = create_async_engine("postgresql+asyncpg://user:pass@host/db", pool_size=20)
AsyncSessionLocal = sessionmaker(engine, class_=AsyncSession, expire_on_commit=False)

async def get_db():
    async with AsyncSessionLocal() as session:
        yield session

@app.get("/users/{id}")
async def get_user(id: int, db: AsyncSession = Depends(get_db)):
    result = await db.execute(select(User).where(User.id == id))
    return result.scalar_one_or_none()

# N+1 query problem — common review flag
# Fix with eager loading:
from sqlalchemy.orm import selectinload
stmt = select(User).options(selectinload(User.posts))

# Alembic for migrations
# alembic revision --autogenerate -m "add users table"
# alembic upgrade head
```

 ## 8. Authentication & Security

 ```python
from fastapi.security import OAuth2PasswordBearer, OAuth2PasswordRequestForm
from jose import jwt

oauth2_scheme = OAuth2PasswordBearer(tokenUrl="token")

@app.post("/token")
async def login(form_data: OAuth2PasswordRequestForm = Depends()):
    user = authenticate(form_data.username, form_data.password)
    access_token = create_jwt(user)
    return {"access_token": access_token, "token_type": "bearer"}

def create_jwt(data: dict, expires_delta: timedelta = timedelta(minutes=15)):
    to_encode = data.copy()
    to_encode["exp"] = datetime.utcnow() + expires_delta
    return jwt.encode(to_encode, SECRET_KEY, algorithm="HS256")

# CORS
from fastapi.middleware.cors import CORSMiddleware
app.add_middleware(
    CORSMiddleware,
    allow_origins=["https://frontend.com"],   # never "*" with allow_credentials=True
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Rate limiting: slowapi (wraps limits) is the common FastAPI-native choice
# Password hashing: passlib[bcrypt] or argon2-cffi — never roll your own
```

 ## 9. Testing

 ```python
from fastapi.testclient import TestClient   # sync, wraps httpx
import pytest
from httpx import AsyncClient, ASGITransport

client = TestClient(app)

def test_read_item():
    response = client.get("/items/1")
    assert response.status_code == 200

# Async test client (preferred for async apps)
@pytest.mark.asyncio
async def test_async_endpoint():
    async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as ac:
        response = await ac.get("/items/1")
    assert response.status_code == 200

# Overriding dependencies for isolated tests
app.dependency_overrides[get_db] = lambda: fake_db_session
```

 ## 10. Validation & Error Handling

 ```python
from fastapi import HTTPException
from fastapi.exceptions import RequestValidationError
from fastapi.responses import JSONResponse

@app.exception_handler(RequestValidationError)
async def validation_exception_handler(request, exc):
    return JSONResponse(status_code=422, content={"detail": exc.errors()})

class AppException(Exception):
    def __init__(self, message: str):
        self.message = message

@app.exception_handler(AppException)
async def app_exception_handler(request, exc: AppException):
    return JSONResponse(status_code=400, content={"error": exc.message})

# Raising standard HTTP errors
raise HTTPException(status_code=404, detail="Item not found")
```

 ## 11. Performance & Production Concerns

 ```python
# ASGI server: Uvicorn (dev) behind Gunicorn with UvicornWorker (prod), for multi-process
# gunicorn app.main:app -k uvicorn.workers.UvicornWorker -w 4

# Connection pooling — size relative to worker count x expected concurrency
# Avoid creating a new DB engine/session per request; reuse a pooled engine

# Response model exclusions for performance & security
class UserOut(BaseModel):
    id: int
    name: str
    model_config = ConfigDict(from_attributes=True)   # formerly orm_mode in v1

# Caching: Redis for shared cache across workers, in-memory (functools.lru_cache)
# only safe for single-process/read-only reference data

# Pydantic validation cost — validate once at the boundary, don't re-validate
# internally on every function call in hot paths

# GZip / compression middleware
from fastapi.middleware.gzip import GZipMiddleware
app.add_middleware(GZipMiddleware, minimum_size=1000)
```

 ## 12. Common Gotchas

 ```python
# Mutable default values in Pydantic — use Field(default_factory=...)
class Bad(BaseModel):
    tags: list = []          # AVOID — though Pydantic handles this safer than
                              # raw Python defaults, still be explicit:
class Good(BaseModel):
    tags: list[str] = Field(default_factory=list)

# Route order matters — more specific paths BEFORE dynamic ones
@app.get("/users/me")        # must be defined before...
async def get_me(): ...
@app.get("/users/{user_id}")  # ...this, or "/users/me" gets swallowed as user_id="me"
async def get_user(user_id: int): ...

# Returning ORM objects directly without response_model can leak internal fields
# or fail serialization on lazy-loaded relationships — always define response models.

# Forgetting `await` on an async dependency/call — silently returns a coroutine object
# instead of the actual value (a very common bug in async codebases)

# Circular imports between routers and models — structure with a clear
# routers/ -> services/ -> models/ -> schemas/ layering

# Using a single global DB session across requests — NOT thread/async-safe;
# always create a new session per request via Depends(get_db)
```

 ## 13. Architecture & Senior-Level Talking Points

 - **Project structure at scale**: `routers/`, `services/` (business logic), `models/` (ORM), `schemas/` (Pydantic), `core/` (config, security), `dependencies/`.
- **Settings management**: `pydantic-settings` `BaseSettings` for typed env-var config, validated at startup.
- **Versioning APIs**: URL prefix (`/v1`, `/v2`) vs header-based versioning — trade-offs of each.
- **Sync vs async DB drivers**: `asyncpg`/`aiomysql` for true async I/O vs running sync drivers in a threadpool.
- **Idempotency & retries**: especially for payment/webhook endpoints.
- **Observability**: structured logging, OpenTelemetry instrumentation for tracing across services.
- **Graceful shutdown**: `@app.on_event("shutdown")` (or lifespan context in newer versions) to close DB pools, flush queues.
- **Lifespan events** (modern replacement for `on_event`):

 ```python
from contextlib import asynccontextmanager

@asynccontextmanager
async def lifespan(app: FastAPI):
    await init_db_pool()
    yield
    await close_db_pool()

app = FastAPI(lifespan=lifespan)
```

 ## 14. Quick Reference: Things You Should Be Able to Explain Live

 - Why `async def` with blocking code is worse than plain `def` for that same blocking code.
- How FastAPI's dependency injection differs from a typical DI container (it's function-based, resolved per-request, supports caching).
- Pydantic v1 vs v2 differences and why the migration mattered (performance, stricter validation).
- WSGI vs ASGI, and why that distinction enables WebSockets/async in FastAPI but not in Flask/Django (pre-ASGI Django).
- How you'd structure a FastAPI app for a large team (module boundaries, shared dependencies, versioning).
- The role of Starlette underneath FastAPI — FastAPI adds validation/docs on top of Starlette's routing/ASGI primitives.