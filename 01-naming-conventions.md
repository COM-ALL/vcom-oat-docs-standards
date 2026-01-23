# Naming Conventions

## File and Pathway Naming Conventions

Display names use: "Section | Section | Section"

Path/URL names use: "section-section-section"

## Tokens

```
Token        = "VCOM OAT" | Domain | System | Artifact | Env | Qual;
Domain       = "VCAT" | "VSTU" | "VENROLL" | "VEVAL" | "VDATA" | "VSITE" | "VFACU";
System       = "TBANNER" | "VELENTRA" | "VPIQ" | "VFACPORT";
Env          = "DEV" | "TEST" | "UAT" | "PROD" | "SBX";
Direction    = "INBOUND" | "OUTBOUND";
Date         = YYYY MM DD;    (* compact: YYYYMMDD as a single token *)
Time         = HH MM;         (* 24-hour: HHMM as a single token *)
Version      = "v" Digit {Digit};
Artifact     = <short, kebab/pascal, platform-specific>;
Qual         = Direction | Date | Time | Version | <purpose>;
```

## Cross‑cutting rules of thumb

1. Keep names ≤ ~50 characters where possible; use tokens, not sentences.
1. Avoid prohibited characters (/ \ : * ? " < > | # % & { } +) and avoid spaces in path/URL contexts.
1. Do not encode semantics twice (e.g., don’t add PROD if the workspace lives only in PROD).
1. Document exceptions (one place in the standards repo).
1. Bake tokens into automation (regex/JSON schema) so deviations are flagged automatically.
