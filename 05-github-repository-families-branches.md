# GitHub: repository families & branches

## repository naming convention
Repository name pattern (kebab‑case):
```
vcom-oat-<family>-<domain>-<system?>-<purpose?>
```

## family

* docs (standards & guidance)
* pm (work tracking templates), code (scripts/apps/packages), data (schemas, seed data)
* code (scripts/apps/packages)
* data (schemas, seed data)

### examples

```
vcom-oat-docs-standards              # top-level standards site
vcom-oat-docs-vdata-data-dictionary  # domain-specific docs
vcom-oat-code-velentra-etl           # code for Elentra ETL
vcom-oat-code-tbanner-connectors    # code for TBanner connectors
```

## branching and tags

```
main
release/<major>.<minor>        # release/1.2
feature/<ticket>-<slug>        # feature/AT-123-users-import
hotfix/<issue>-<slug>          # hotfix/bug-456-fix-null
tags: v1.2.0, v1.2.1
```

## Folders inside the “standards” repo

```
/standards/
  00-introduction.md
  01-naming-conventions.md
  02-data-formats.md
  03-security-and-classification.md
  04-versioning-and-releases.md
  05-quality-and-testing.md
/glossary/
/examples/
CONTRIBUTING.md
README.md
```