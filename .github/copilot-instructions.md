# VCOM OAT Data Standards Copilot Instructions

## Project Overview
This repository defines data standardization patterns for Virginia College of Osteopathic Medicine's Office of Academic Technology (OAT), covering seven business domains (VCAT, VSTU, VENROLL, VEVAL, VDATA, VSITE, VFACU) across four systems (TBANNER, VELENTRA, VPIQ, VFACPORT). The project includes naming conventions, Power Query functions, mapping files, and AI prompts for consistent data management.

## Architecture & Key Patterns

### Domain-Driven Naming Convention
- **Global Token Order**: `<OrgUnit>-<Domain>-<System>-<Artifact>-<Env>-<Qualifiers>`
- **Display Names**: Use `|` separators in Title Case (e.g., "VCOM OAT | VDATA | VELENTRA | Users | INBOUND | DEV")
- **Internal Names**: Use `lower_snake_case` (e.g., `vcom_vdata_velentra_users_inbound_dev`)
- **Domains**: `VCAT` (courses), `VSTU` (students), `VENROLL` (enrollment), `VEVAL` (evaluation), `VDATA` (data), `VSITE` (sites), `VFACU` (faculty)
- **Systems**: `TBANNER`, `VELENTRA`, `VPIQ`, `VFACPORT`
- **Environments**: `DEV`, `TEST`, `UAT`, `PROD`, `SBX`

### UID Generation Pattern
All UID generator functions follow this structure:
- Input normalization using `fnNormalizeText()` or `fnNormalizeStudentId()`
- Validation of required inputs
- Conditional UID construction with null-safe handling
- See [fn-uid-function library/VCOM-OAT-VENROLL-UID-GENERATOR/](fn-uid-function%20library/VCOM-OAT-VENROLL-UID-GENERATOR/) for examples

### Power Query Code Conventions
- Functions named with descriptive prefixes: `fnBuild`, `fnNormalize`, `fn`
- Version suffixes: `_v1`, `_v2` for function evolution
- Null-safe conditional logic with early validation
- Standardized parameter naming: `stu_uniqueid`, `mdco_courseuid`

### Cross-System Data Mapping
Master mapping files in [MDCO_MAPPING_verified/](MDCO_MAPPING_verified/) maintain course UID consistency across systems:
- `VCOM-OAT-DATA-BANNER-CRSUID_map-master.csv`
- `VCOM-OAT-DATA-ELENTRA-CRSUID-master.csv`
- `VCOM-OAT-DATA-MDCO-CRSUID-master.csv`
- `VCOM-OAT-DATA-PIQ-CRSUID_map-master.csv`

## AI Assistant Usage Patterns

### Built-in AI Prompts
Use existing prompts from [ai-prompt-library/](ai-prompt-library/) for consistent naming:
- **Dataverse Tables**: Display name format `"<System> <Dataset>"`, logical name `"vcom_<system>_<dataset>_s"`
- **Dataflows**: Display format with pipe separators, internal format with underscores
- **Cloud Flows**: Include action verbs in display names
- Reference [04-prompt-card.txt](ai-prompt-library/04-prompt-card.txt) for complete naming rules

### Naming Generation Workflow
1. Identify artifact type (table/dataflow/flow)
2. Determine domain, system, dataset, direction, environment
3. Apply controlled vocabulary from [01-naming-conventions.md](01-naming-conventions.md)
4. Generate both display and internal names
5. Validate against 50-character limit where possible

## Development Guidelines

### File Organization
- Standards documents: Numbered 01-15 for sequential reading
- Function libraries: Versioned in domain-specific folders
- Student queries: Separate folder for PIQ-related transformations
- Audit scripts: Python for data validation and consistency checks

### Adding New Standards
1. Follow existing numbering scheme (01-XX.md)
2. Include practical examples from actual usage
3. Update [README.md](README.md) if adding new domains or systems
4. Consider impact on existing AI prompts and automation

### Power Query Development
- Use established normalization functions before building UIDs
- Implement null-safe conditional logic
- Version functions when making breaking changes
- Test with real data from mapping files
- For new code: Use `_` (underscores) in column names, not `-` (hyphens)
- Include query title as comment on the first line (e.g., `// stg_StudentTags_Long`) for easier pasting and naming

### Cross-Platform Considerations
- Avoid prohibited characters: `/ \ : * ? " < > | # % & { } +`
- Design for machine readability (sortable, parseable)
- Maintain consistency between SharePoint, Power Platform, and GitHub naming