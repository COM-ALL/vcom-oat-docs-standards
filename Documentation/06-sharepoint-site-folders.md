# SharePoint: site/folder structure & file names

Rationale: predictable, sortable, easy for flows to parse.

## Top‑level library structure:

```
VCOM-OAT/
  <Domain>/
    <System>/
      inbound/
      outbound/
      archive/
```

## Folder names (kebab‑case, short):

```
vcom-oat/
  vdata/
    velentra/
      inbound/
      outbound/
      archive/2026/
```

## File name pattern (CSV or artifacts):

```
<System>_<Dataset>_<INBOUND|OUTBOUND>_<YYYYMMDD>_<HHMM?>_<v#?>.csv
```

## Examples:

```
VELENTRA_users_INBOUND_20260123_0830.csv
TBANNER_courses_OUTBOUND_20260123_v2.csv
```
