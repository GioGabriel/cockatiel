---
inclusion: fileMatch
fileMatchPattern: "backend/**/modules/**/*.py,backend/**/api/**/*.py"
---

# Backend Service Patterns (loaded when working on backend modules)

## Service Function Template

```python
def do_something(
  session_id: str,
  user_id: str,
  *,
  param: str,
  optional_param: dict[str, Any] | None = None,
) -> dict[str, Any]:
  """Keyword-only params after * for clarity. Return typed dicts or Pydantic models."""
  repository = get_session_repository()
  session = _get_validated_session(session_id, user_id)

  # Business logic here (pure computation preferred)
  result = _compute_result(session, param)

  # Single repository write at the end
  updated = repository.update(session_id, {"field": result})
  if not updated:
    raise ApiError(code="NOT_FOUND", message="Resource not found.", status_code=404)
  return updated
```

## Endpoint Template

```python
from fastapi import APIRouter, Depends

from app.api.v1.dependencies import get_current_user_id
from app.api.v1.schemas import MyRequestIn, MyResponseOut
from app.modules.my_module.service import do_something

router = APIRouter(prefix="/v1/my-resource", tags=["my-resource"])


@router.post("/{resource_id}/action", response_model=MyResponseOut)
def perform_action(
  resource_id: str,
  body: MyRequestIn,
  user_id: str = Depends(get_current_user_id),
) -> MyResponseOut:
  result = do_something(
    resource_id=resource_id,
    user_id=user_id,
    param=body.param,
  )
  return MyResponseOut(**result)
```

## Error Raising Pattern

```python
# Always use domain-specific codes
raise ApiError(
  code="SESSION_MODE_INVALID",
  message="Training attempts can only be saved for training sessions.",
  status_code=409,
)

# Status code guide:
# 400 = validation / bad input
# 401 = unauthenticated
# 403 = unauthorized
# 404 = resource not found
# 409 = conflict / state violation
# 422 = Pydantic validation (handled globally)
# 500 = unexpected (handled globally)
```

## Repository Access Rules

- Always go through `get_*_repository()` factory functions.
- Never import Firestore or storage clients directly in service modules.
- Repository methods: `create()`, `get()`, `update()`, `list_by_user()`, `delete()`.
- Return `None` from `get()` if not found (let service decide error behavior).

## Metric Summary Pattern (for AI context)

```python
summary: dict[str, float | int] = {
  "metric_mode": "voice",
  "sample_count": len(metrics),
  "first_timestamp_ms": min(timestamps),
  "last_timestamp_ms": max(timestamps),
}
for field in METRIC_FIELDS:
  summary[field] = round(
    sum(float(m.get(field, 0.0)) for m in metrics) / len(metrics), 2
  )
```
