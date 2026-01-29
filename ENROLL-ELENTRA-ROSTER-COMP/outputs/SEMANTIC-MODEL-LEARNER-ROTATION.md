# LEARNER ROTATION SEMANTIC MODEL - Complete Workflow

## Overview
This semantic model provides a comprehensive business intelligence layer for the LEARNER-ROTATION-DATASET, enabling sys-management dashboards with consistent metrics, relationships, and drill-through capabilities.

## Table Architecture

### Fact Tables (Metrics)
1. **DASHBOARD-SOURCE-COUNTS** - Primary fact table for source system metrics
2. **DASHBOARD-MATCH-ANALYSIS** - Match analysis metrics for non-AIM populations
3. **DASHBOARD-DEDUPLICATION-LOG** - Data quality and deduplication metrics

### Dimension Tables (Detail/Drill-through)
4. **DASHBOARD-ELENTRA-UNRESOLVED** - Detailed Elentra-only rotation records
5. **DASHBOARD-PIQ-UNRESOLVED** - Detailed PIQ-only rotation records

## Table Relationships

### Primary Relationships
```
DASHBOARD-SOURCE-COUNTS (1) → (*) DASHBOARD-ELENTRA-UNRESOLVED
- Via: SOURCE_SYSTEM = "ELENTRA" AND POPULATION = "NON-AIM"
- Direction: Single (Source to Detail)

DASHBOARD-SOURCE-COUNTS (1) → (*) DASHBOARD-PIQ-UNRESOLVED  
- Via: SOURCE_SYSTEM = "PIQ" AND POPULATION = "NON-AIM"
- Direction: Single (Source to Detail)

DASHBOARD-MATCH-ANALYSIS (*) → (*) DASHBOARD-ELENTRA-UNRESOLVED
- Via: MATCH_TYPE = "ELENTRA_NO_MATCH"
- Bridge: Many-to-Many via shared context

DASHBOARD-MATCH-ANALYSIS (*) → (*) DASHBOARD-PIQ-UNRESOLVED
- Via: MATCH_TYPE = "PIQ_NO_MATCH" 
- Bridge: Many-to-Many via shared context
```

### Date Table (Shared)
```
DimDate (1) → (*) ALL TABLES via LAST_UPDATED field
- Enables time-series analysis and refresh tracking
```

## Key Measures (DAX)

### Source Count Measures
```dax
Total Elentra Rotations = 
CALCULATE(
    SUM('DASHBOARD-SOURCE-COUNTS'[COUNT_ROTATION_BOOKINGS]),
    'DASHBOARD-SOURCE-COUNTS'[SOURCE_SYSTEM] = "ELENTRA",
    'DASHBOARD-SOURCE-COUNTS'[POPULATION] = "ALL"
)

Total PIQ Rotations = 
CALCULATE(
    SUM('DASHBOARD-SOURCE-COUNTS'[COUNT_ROTATION_BOOKINGS]),
    'DASHBOARD-SOURCE-COUNTS'[SOURCE_SYSTEM] = "PIQ",
    'DASHBOARD-SOURCE-COUNTS'[POPULATION] = "ALL"
)

Non-AIM Elentra Count = 
CALCULATE(
    SUM('DASHBOARD-SOURCE-COUNTS'[COUNT_ROTATION_BOOKINGS]),
    'DASHBOARD-SOURCE-COUNTS'[SOURCE_SYSTEM] = "ELENTRA",
    'DASHBOARD-SOURCE-COUNTS'[POPULATION] = "NON-AIM"
)

Non-AIM PIQ Count = 
CALCULATE(
    SUM('DASHBOARD-SOURCE-COUNTS'[COUNT_ROTATION_BOOKINGS]),
    'DASHBOARD-SOURCE-COUNTS'[SOURCE_SYSTEM] = "PIQ",
    'DASHBOARD-SOURCE-COUNTS'[POPULATION] = "NON-AIM"
)
```

### Match Analysis Measures
```dax
Matched Rotations = 
CALCULATE(
    SUM('DASHBOARD-MATCH-ANALYSIS'[COUNT_NON_AIM_ROTATIONS]),
    'DASHBOARD-MATCH-ANALYSIS'[MATCH_TYPE] = "MATCHED_ROTATION_BOOKINGS"
)

Elentra Unmatched = 
CALCULATE(
    SUM('DASHBOARD-MATCH-ANALYSIS'[COUNT_NON_AIM_ROTATIONS]),
    'DASHBOARD-MATCH-ANALYSIS'[MATCH_TYPE] = "ELENTRA_NO_MATCH"
)

PIQ Unmatched = 
CALCULATE(
    SUM('DASHBOARD-MATCH-ANALYSIS'[COUNT_NON_AIM_ROTATIONS]),
    'DASHBOARD-MATCH-ANALYSIS'[MATCH_TYPE] = "PIQ_NO_MATCH"
)

Match Rate % = 
VAR TotalNonAIM = [Non-AIM Elentra Count] + [Non-AIM PIQ Count] - [Matched Rotations]
RETURN
DIVIDE([Matched Rotations], TotalNonAIM, 0)
```

### Data Quality Measures
```dax
Total Duplicates Removed = 
SUMX(
    'DASHBOARD-DEDUPLICATION-LOG',
    'DASHBOARD-DEDUPLICATION-LOG'[DUPLICATES_REMOVED]
)

Data Quality Score = 
VAR TotalOriginal = SUMX('DASHBOARD-DEDUPLICATION-LOG', 'DASHBOARD-DEDUPLICATION-LOG'[ORIGINAL_COUNT])
VAR TotalDuplicates = [Total Duplicates Removed]
RETURN
1 - DIVIDE(TotalDuplicates, TotalOriginal, 0)

Worst Duplication Table = 
TOPN(
    1,
    'DASHBOARD-DEDUPLICATION-LOG',
    'DASHBOARD-DEDUPLICATION-LOG'[DEDUP_PERCENTAGE],
    DESC
)[TABLE_NAME]
```

### Migration Progress Measures
```dax
Migration Coverage % = 
VAR ElentraTotal = [Non-AIM Elentra Count]
VAR PIQTotal = [Non-AIM PIQ Count]
VAR Matched = [Matched Rotations]
RETURN
DIVIDE(Matched, PIQTotal, 0)

Migration Readiness Score = 
VAR MatchRate = [Match Rate %]
VAR DataQuality = [Data Quality Score]
RETURN
(MatchRate * 0.7) + (DataQuality * 0.3)
```

## Calculated Columns

### Source Counts Enhancement
```dax
// In DASHBOARD-SOURCE-COUNTS
System-Population Key = 
'DASHBOARD-SOURCE-COUNTS'[SOURCE_SYSTEM] & " | " & 'DASHBOARD-SOURCE-COUNTS'[POPULATION]

Is Current Data = 
'DASHBOARD-SOURCE-COUNTS'[LAST_UPDATED] = MAX('DASHBOARD-SOURCE-COUNTS'[LAST_UPDATED])
```

### Match Analysis Enhancement  
```dax
// In DASHBOARD-MATCH-ANALYSIS
Match Category Group = 
SWITCH(
    'DASHBOARD-MATCH-ANALYSIS'[MATCH_TYPE],
    "MATCHED_ROTATION_BOOKINGS", "SUCCESS",
    "ELENTRA_NO_MATCH", "NEEDS_ATTENTION", 
    "PIQ_NO_MATCH", "NEEDS_ATTENTION",
    "LONGITUDINAL_PATTERN", "INFORMATIONAL",
    "OTHER"
)
```

## Security Model

### Row Level Security (RLS)
```dax
// For department-specific access
Department Filter = 
USERPRINCIPALNAME() IN {
    "oat-admin@vcom.edu",
    "data-team@vcom.edu",
    "registrar@vcom.edu"
}
```

## Refresh Strategy

### Incremental Refresh Settings
- **Source Tables**: Daily at 6 AM EST
- **Dashboard Tables**: Hourly during business hours (8 AM - 6 PM EST)
- **Detection**: Based on LAST_UPDATED field
- **Historical Retention**: 2 years for trending analysis

### Dependencies
```
Datalake Tables → Dashboard Tables → Semantic Model → Power BI Reports
```

## Usage Patterns

### Primary Dashboard Views
1. **Executive Summary**: High-level migration progress and data quality
2. **System Comparison**: Side-by-side Elentra vs PIQ metrics  
3. **Unresolved Details**: Drill-through to specific unmatched records
4. **Data Quality Monitor**: Deduplication and consistency metrics
5. **Trend Analysis**: Historical progression of migration metrics

### Drill-Through Configuration
- **From**: Match analysis cards
- **To**: Detailed unresolved tables
- **Filter**: Pass system and match type context
- **Return**: All available columns for investigation

## Standard Naming Convention
- **Measures**: `[Descriptive Name]` with units (e.g., `[Match Rate %]`)
- **Calculated Columns**: `Column Purpose` (e.g., `System-Population Key`)
- **Tables**: `DASHBOARD-FUNCTIONALITY` pattern
- **Relationships**: Named for business meaning

This semantic model establishes a reusable pattern for sys-management dashboards across all VCOM OAT data domains.