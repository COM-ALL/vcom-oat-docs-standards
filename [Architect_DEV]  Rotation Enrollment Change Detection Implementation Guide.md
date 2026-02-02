# VCOM OAT Rotation Enrollment Change Detection Implementation Guide

## Overview
This document outlines the implementation for detecting adds/drops in student rotation enrollments using the `MDCO_ENROLL_LRN_ROTATION_UID` value from the established `[dbo].[MDCO-ENROLL-ELENTRA-ROTATIONS-ACTIVE]` dataset.

## Architecture Decision
Based on VCOM OAT standards for **Data Layer Architecture & Reuse Principle**, this solution leverages the established `MDCO-ENROLL-ELENTRA-ROTATIONS-ACTIVE` dataset and creates a secondary change tracking table following the **Two-Tier Pattern**.

## Implementation Components

### 1. Version Capture Table

````powerquery
// vcom_oat_venroll_rotation_versions
// VCOM OAT | VENROLL | ELENTRA | Rotation Versions | INBOUND | DEV
let
    Source = Lakehouse.Contents(),
    ActiveRotations = Source{[Schema="dbo",Item="MDCO-ENROLL-ELENTRA-ROTATIONS-ACTIVE"]}[Data],
    
    // Add version metadata following established patterns
    AddVersionTimestamp = Table.AddColumn(
        ActiveRotations, 
        "version_timestamp", 
        each DateTime.LocalNow(),
        type datetime
    ),
    
    AddVersionId = Table.AddColumn(
        AddVersionTimestamp,
        "version_id", 
        each Text.From(Date.Year([version_timestamp])) & 
             Text.PadStart(Text.From(Date.Month([version_timestamp])), 2, "0") & 
             Text.PadStart(Text.From(Date.Day([version_timestamp])), 2, "0"),
        type text
    ),
    
    // Select only necessary columns for change detection
    SelectColumns = Table.SelectColumns(
        AddVersionId,
        {"MDCO_ENROLL_LRN_ROTATION_UID", "version_timestamp", "version_id"}
    )
in
    SelectColumns
`````

### 2. Change Detection Table

````powerquery
// vcom_oat_venroll_rotation_changes
// VCOM OAT | VENROLL | ELENTRA | Rotation Changes | INBOUND | DEV
let
    Source = Lakehouse.Contents(),
    VersionTable = Source{[Schema="dbo",Item="vcom_oat_venroll_rotation_versions"]}[Data],
    
    // Get latest two versions using established UID patterns
    VersionList = List.Distinct(VersionTable[version_id]),
    SortedVersions = List.Sort(VersionList, Order.Descending),
    
    CurrentVersionId = if List.Count(SortedVersions) > 0 then SortedVersions{0} else null,
    PreviousVersionId = if List.Count(SortedVersions) > 1 then SortedVersions{1} else null,
    
    // Extract current rotation UIDs
    CurrentData = Table.SelectRows(
        VersionTable, 
        each [version_id] = CurrentVersionId
    ),
    CurrentUIDs = if Table.IsEmpty(CurrentData) then {} else CurrentData[MDCO_ENROLL_LRN_ROTATION_UID],
    
    // Extract previous rotation UIDs
    PreviousData = if PreviousVersionId = null 
        then Table.FromRows({}, {"MDCO_ENROLL_LRN_ROTATION_UID"})
        else Table.SelectRows(VersionTable, each [version_id] = PreviousVersionId),
    PreviousUIDs = if Table.IsEmpty(PreviousData) then {} else PreviousData[MDCO_ENROLL_LRN_ROTATION_UID],
    
    // Identify drops (existed in previous, not in current)
    Drops = Table.SelectRows(
        PreviousData, 
        each not List.Contains(CurrentUIDs, [MDCO_ENROLL_LRN_ROTATION_UID])
    ),
    
    // Identify adds (exists in current, not in previous)
    Adds = Table.SelectRows(
        CurrentData, 
        each not List.Contains(PreviousUIDs, [MDCO_ENROLL_LRN_ROTATION_UID])
    ),
    
    // Tag change types for CSV generation
    DropsTagged = Table.AddColumn(Drops, "change_type", each "DROP", type text),
    AddsTagged = Table.AddColumn(Adds, "change_type", each "ADD", type text),
    
    // Combine all changes
    AllChanges = Table.Combine({DropsTagged, AddsTagged}),
    
    // Add processing metadata
    AddChangeTimestamp = Table.AddColumn(
        AllChanges, 
        "change_detected", 
        each DateTime.LocalNow(),
        type datetime
    )
in
    AddChangeTimestamp
```

## PIQ Export Generation (Drops Focus)

``````
This is the code block that represents the suggested code change:
```markdown
// vcom_oat_venroll_piq_rotation_export
// VCOM OAT | VENROLL | PIQ | Rotation Export | OUTBOUND | DEV
let
    Source = Lakehouse.Contents(),
    
    // Get current active rotations for full schedule
    ActiveRotations = Source{[Schema="dbo",Item="MDCO-ENROLL-ELENTRA-ROTATIONS-ACTIVE"]}[Data],
    
    // Get detected changes
    Changes = Source{[Schema="dbo",Item="vcom_oat_venroll_rotation_changes"]}[Data],
    
    // Filter for drops only (current requirement)
    Drops = Table.SelectRows(Changes, each [change_type] = "DROP"),
    
    // Add action flag to active rotations (current schedule)
    ActiveWithAction = Table.AddColumn(
        ActiveRotations, 
        "piq_action", 
        each "CURRENT",
        type text
    ),
    
    // Add action flag to drops
    DropsWithAction = Table.Join(
        Drops,
        {"MDCO_ENROLL_LRN_ROTATION_UID"},
        ActiveRotations,
        {"MDCO_ENROLL_LRN_ROTATION_UID"},
        JoinKind.LeftOuter
    ),
    
    DropsFormatted = Table.ReplaceValue(
        DropsWithAction,
        null,
        "DROP",
        Replacer.ReplaceValue,
        {"piq_action"}
    ),
    
    // Combine for PIQ export
    PIQExport = Table.Combine({ActiveWithAction, DropsFormatted}),
    
    // Select columns for CSV generation (customize based on PIQ requirements)
    FinalExport = Table.SelectColumns(
        PIQExport,
        {"MDCO_ENROLL_LRN_ROTATION_UID", "piq_action", "version_timestamp"}
    )
in
    FinalExport
```

Developer Setup Instructions
Step 1: Prerequisites
Access to established [dbo].[MDCO-ENROLL-ELENTRA-ROTATIONS-ACTIVE] table
Lakehouse with appropriate permissions
Power Query development environment
Step 2: Implementation Sequence
Create Version Table (Day 1)

Deploy vcom_oat_venroll_rotation_versions query
Schedule daily refresh to capture snapshots
Verify MDCO_ENROLL_LRN_ROTATION_UID values are captured correctly
Deploy Change Detection (Day 2)

Deploy vcom_oat_venroll_rotation_changes query
Test with sample data to verify ADD/DROP logic
Validate against known rotation changes
Setup PIQ Export (Day 3)

Deploy vcom_oat_venroll_piq_rotation_export query
Configure CSV generation workflow

Step 3: Validation & Testing
```````
This is the code block that represents the suggested code change:
```markdown
// Test Query: Validate change detection
let
    Changes = Lakehouse.Contents(){[Schema="dbo",Item="vcom_oat_venroll_rotation_changes"]}[Data],
    Summary = Table.Group(
        Changes, 
        {"change_type"}, 
        {"Count", each Table.RowCount(_), type number}
    )
in
    Summary
```

Step 4: Future Extensions
For ADD Notifications (Future Phase):

Filter change table for change_type = "ADD"
Integrate with Power Automate for notification triggers
Add student contact information joins for email alerts
Alternative: Flag-in-Main-Table Approach:
If preferred, add rotation_status column directly to MDCO-ENROLL-ELENTRA-ROTATIONS-ACTIVE:

ACTIVE: Current enrollment
DROPPED: Marked for removal
NEW: Recently added
Performance Considerations
Version Table Size: Grows daily, consider archival strategy after 90 days
Change Detection: Runs efficiently on UID comparisons only
Export Generation: Minimal overhead using established datasets
Integration Points
Power Automate: Trigger CSV generation on change detection
PIQ API: Future integration point for real-time updates
Notification System: Use ADD flags for automated alerts
Domain & Naming Standards
This implementation follows VENROLL domain patterns:

Domain: VENROLL (student enrollment data)
System: ELENTRA (source system)
Direction: INBOUND (data flowing into lakehouse)
Environment: DEV (development environment)
All table names follow the established pattern:

Display: "VCOM OAT | VENROLL | ELENTRA | <Dataset> | INBOUND | DEV"
Internal: vcom_oat_venroll_<dataset>_inbound_dev
This implementation follows VCOM OAT standards for reusing established datasets while providing the flexibility needed for both immediate DROP processing and future ADD notification requirements.