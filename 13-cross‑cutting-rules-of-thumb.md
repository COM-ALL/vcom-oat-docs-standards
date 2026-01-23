# Cross‑cutting rules of thumb

1. Keep names ≤ ~50 characters where possible; use tokens, not sentences.
1. Avoid prohibited characters (/ \ : * ? " < > | # % & { } +) and avoid spaces in path/URL contexts.
1. Do not encode semantics twice (e.g., don’t add PROD if the workspace lives only in PROD).
1. Document exceptions (one place in the standards repo).
1. Bake tokens into automation (regex/JSON schema) so deviations are flagged automatically.