# Cache and Firestore Read Policy

Cockatiel uses short-lived, process-local caches only where the response is
safe to reuse and the source of truth remains Firestore. Cache entries are
defensively copied, bounded by capacity, and loaded with per-key single-flight
coalescing. A loader failure is never cached.

## Current policies

| Resource | Key | TTL | Capacity | Invalidation |
| --- | --- | ---: | ---: | --- |
| Session list | Firebase user ID | 30 seconds | 256 users | Any session create/update clears the repository cache |
| Analytics dashboard | Firebase user ID | 5 minutes | 512 users | Completed-session rollup invalidates that user |
| Analytics trends | Firebase user ID + `7d`, `30d`, or `90d` | 5 minutes | 1,024 keys | Completed-session rollup invalidates that user’s supported ranges |
| Karaoke catalog | environment/config context | 10 minutes | 8 contexts | Explicit catalog reset |
| Karaoke drill | environment/config context + drill ID | 10 minutes | 512 keys | Explicit catalog reset; missing drills are negative-cached |

The cache metrics are exposed through the existing protected `/metrics`
endpoint. Names use the form
`cache_<resource>_{hit,miss,singleflight_wait,load,load_error,invalidate,invalidate_all,eviction}_total`.
They contain counts only; no user IDs, documents, credentials, audio, or
provider payloads are recorded.

## Freshness and consistency

Process-local caching does not provide cross-worker consistency. A Render
deployment with multiple workers can therefore serve a value until its local
TTL expires, even after another worker writes. Write paths invalidate the local
cache where the repository has sufficient context; the short TTL is the
fallback for writes made by another process. Explicit refresh paths must still
issue a new request and must not be implemented as cache reads.

The session repository currently clears its complete bounded session cache on a
write because a write/update call may not have enough trusted context to prove
which cached user lists contain that session. This is conservative and safe,
but less efficient than user-key invalidation. If write records later carry a
verified owner ID, invalidation can be narrowed without weakening isolation.

Analytics retains a legacy fallback that reads session history when daily
rollups are absent. This preserves compatibility with older documents; it is
not a claim that analytics is fully rollup-backed. The `/ai/jobs` path also
derives active jobs from a user’s session list. A dedicated indexed active-job
document/query would reduce those reads further, but would require a separate
data-model and operational change and is intentionally outside this hardening
pass.

## Why Redis was not added

The current bounded caches reduce repeated reads without adding an external
dependency, invalidation protocol, or new secret/configuration surface. Redis
becomes justified when measured multi-worker staleness or cache-miss volume is
material enough to pay for shared-cache operations. Until then, indexed
queries, pagination, rollups, and dedicated active-job summaries are the lower
risk structural read reductions to measure next.
