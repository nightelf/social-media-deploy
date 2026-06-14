# FastAPI vs Django REST Framework — side by side

Both backends in this project implement the **same** [API contract](./API_CONTRACT.md), so they're a
controlled experiment: identical behavior, two idiomatic implementations. This doc maps the concepts
so you can see how each framework does the same job. File paths are relative to each backend repo.

| Concern | FastAPI (`social-media-backend-fastapi`) | Django REST Framework (`social-media-backend-django`) |
|---|---|---|
| App entry | `app/main.py` creates `FastAPI()`, includes routers | `config/urls.py` + `manage.py`; apps in `INSTALLED_APPS` |
| Project shape | flat `app/` package, routers per resource | `config/` project + per-feature `apps/` |
| ORM | SQLAlchemy 2.0 **async** (`app/models.py`) | Django ORM (`apps/*/models.py`) |
| Migrations | **Alembic** (`alembic/`, autogenerate) | **Django migrations** (`makemigrations`/`migrate`) |
| Schemas / serialization | **Pydantic** models (`app/schemas.py`) | **DRF serializers** (`apps/*/serializers.py`) |
| Validation | Pydantic types + manual checks → 422 | Serializer `validate_*` / fields → 400→mapped 422 |
| Routing | `APIRouter` + path-operation functions | DRF `ViewSet` + `DefaultRouter` (and `APIView`) |
| Request parsing | function params + Pydantic body models | `request.data` + serializers |
| Auth (JWT) | `python-jose`, hand-rolled in `app/security.py` | `djangorestframework-simplejwt` |
| Current user | `Depends(get_current_user)` (`app/deps.py`) | `permission_classes` + `request.user` |
| Password/code hashing | `passlib` pbkdf2_sha256 (`app/security.py`) | Django `make_password`/`check_password` |
| Pagination | manual `offset/limit` + count (`app/deps.py`) | `PageNumberPagination` subclass (`apps/common/pagination.py`) |
| Error envelope | exception handlers (`app/errors.py`) | custom `EXCEPTION_HANDLER` (`apps/common/exceptions.py`) |
| Config | `pydantic-settings` (`app/config.py`) | `django-environ` (`config/settings/base.py`) |
| Background/CLI | `python -m app.seed`; `BackgroundTasks` | management commands (`manage.py seed`) |
| OpenAPI docs | built in (`/docs`, `/openapi.json`) | `drf-spectacular` (`/docs`, `/schema`) |
| Admin UI | none (build your own) | Django admin (`/admin`) |
| Concurrency | async/await end-to-end | synchronous (WSGI) |

## Same endpoint, two ways

### "Create a post"

**FastAPI** — `app/routers/posts.py`
```python
@router.post("", response_model=PostOut, status_code=201)
async def create_post(data: PostIn, user=Depends(get_current_user), db=Depends(get_db)):
    post = Post(author_id=user.id, body=data.body)
    db.add(post); await db.commit()
    row = await _fetch_one(db, post.id, user.id)   # re-read with like/comment annotations
    return _post_out(*row)
```
- Body validated by the `PostIn` Pydantic model; response shaped by `PostOut`.
- `Depends(...)` injects the DB session and the authenticated user.
- Counts/`liked_by_me` come from correlated scalar subqueries.

**DRF** — `apps/posts/views.py`
```python
class PostViewSet(viewsets.ModelViewSet):
    serializer_class = PostSerializer
    def get_queryset(self):
        return Post.objects.annotate(
            like_count=Count("likes", distinct=True),
            comment_count=Count("comments", distinct=True),
            liked_by_me=Exists(Like.objects.filter(post=OuterRef("pk"), user=self.request.user.id)),
        ).order_by("-created_at", "-id")
    def create(self, request, *a, **k):
        s = self.get_serializer(data=request.data); s.is_valid(raise_exception=True)
        post = Post.objects.create(author=request.user, body=s.validated_data["body"])
        return Response(self.get_serializer(self.get_queryset().get(pk=post.pk)).data, status=201)
```
- One `ViewSet` provides list/create/retrieve/destroy; the router maps URLs.
- `annotate()` adds counts and `liked_by_me` in the query.

## Gotchas this project hit (good learning notes)
- **DRF default ordering vs `annotate()`**: `Meta.ordering` can be dropped once you `annotate()` aggregates.
  Fix: set ordering explicitly (`.order_by("-created_at", "-id")`). FastAPI orders explicitly too, so
  both feeds match.
- **Datetime format**: DRF renders UTC as `...Z`; Pydantic defaults to `+00:00`. The FastAPI side uses a
  `PlainSerializer` (`app/schemas.py`) to emit `Z` so responses are byte-for-byte identical.
- **Trailing slashes**: DRF routers append `/` by default; here the router uses `trailing_slash=""` to
  match the contract's slash-less paths (and FastAPI's).
- **Two-step login**: neither framework's built-in login fits "validate password, then require a 2FA
  code." Both implement it by hand — DRF with custom `APIView`s, FastAPI with plain path operations —
  minting tokens only at the final `verify` step.

## Try it
With the stack up (see [README](./README.md)), the same requests hit either backend:
```bash
curl http://fastapi.localhost/api/health   # {"status":"ok","backend":"fastapi"}
curl http://django.localhost/api/health    # {"status":"ok","backend":"django"}
```
Open `http://fastapi.localhost` and `http://django.localhost` — the **same** Next.js app, each talking
to a different backend.
