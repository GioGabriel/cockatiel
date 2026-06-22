# Coding Standards

Standards for consistent, clean code across the Vocal Coach monorepo.

## General

- 2-space indentation for all files (enforced by `.editorconfig`).
- UTF-8 encoding, LF line endings.
- Insert final newline in every file.
- Maximum line length: 120 characters (Python), 80 preferred for Dart.
- No unused imports. No dead code. No commented-out code in production files.

## Python (Backend)

### Naming

- `snake_case` for modules, functions, variables, and parameters.
- `PascalCase` for classes (including Pydantic models and dataclasses).
- `UPPER_SNAKE_CASE` for module-level constants.
- Private helpers prefixed with `_` (e.g., `_classify_model_exception`).

### Type Hints

- All function signatures MUST have type annotations (params and return).
- Use `dict[str, Any]` over `Dict[str, Any]` (Python 3.11+ syntax).
- Use `list[str]` over `List[str]`.
- Use `X | None` over `Optional[X]`.
- Use `tuple[str, ...]` for immutable sequences.

### Functions

- Keep functions under 40 lines. If longer, extract helpers.
- Prefer early returns over deep nesting.
- Pure functions where possible; side effects at the top of the call chain.

### Imports

- Standard library first, then third-party, then project-local (separated by blank lines).
- Use absolute imports from the project root (`from app.modules.sessions.service import ...`).

### Testing

- Tests in `tests/unit/` and `tests/integration/`.
- Use `pytest` fixtures for shared setup.
- Test file naming: `test_<module_name>.py`.
- Integration tests hit real endpoints via `httpx.AsyncClient`.

## Dart (Mobile)

### Naming

- `lowerCamelCase` for variables, functions, parameters.
- `UpperCamelCase` for classes, enums, typedefs, type parameters.
- `_lowerCamelCase` for private members.
- File names: `snake_case.dart`.

### Class Design

- Prefer `final` fields and immutable models.
- Use named parameters with `required` for mandatory fields.
- Factory constructors (`fromJson`) for deserialization.
- Keep widget classes focused: one widget = one responsibility.

### Widget Best Practices

- Extract repeated UI into reusable widgets in `shared/widgets/`.
- Prefer `const` constructors wherever possible.
- Use `ListView.builder` for lists (never build all items eagerly).
- Use `SizedBox` over `Container` when you only need spacing.
- Avoid `MediaQuery` for responsive layout; prefer `LayoutBuilder` or `FractionallySizedBox`.

### Async Patterns

- Always handle errors in async calls (try/catch or `.catchError`).
- Dispose subscriptions and timers in `dispose()`.
- Use `mounted` check before calling `setState` after async gaps.

### Imports

- Dart SDK imports first, then packages, then relative project imports.
- Prefer relative imports within the same feature module.
- Use absolute imports (`package:vocal_coach_app/...`) for cross-feature references.

## Contracts-First Development

1. Define or update the contract in `contracts/` first.
2. Implement the backend endpoint against the contract schema.
3. Generate or update mobile DTOs to match.
4. Never let implementation drift from contracts without updating the contract.
