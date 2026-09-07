"""Helpers for classifying persistence failures without leaking provider details."""


def is_storage_quota_exhausted(error: BaseException) -> bool:
  """Return whether a provider reported an exhausted storage quota.

  Firestore is an optional development dependency, so this module deliberately
  uses the provider exception's stable class name instead of importing the SDK
  at application import time. The production log still retains the concrete
  exception type while the HTTP response stays provider-neutral.
  """
  return type(error).__name__ == "ResourceExhausted"
