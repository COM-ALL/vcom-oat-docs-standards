# Power BI Dashboard - Drop-In Ready Configuration

## Page 1: Executive Summary (Main Dashboard)

### Top Row - Key Metrics Cards
**4 Card Visuals in a row:**

**Card 1: Total Elentra Rotations**
- Visual: Card
- Measure: `[Total Elentra Rotations]`
- Title: "Elentra Rotations"
- Color: #0078D4 (Blue)
- Format: Whole number, no decimals

**Card 2: Total PIQ Rotations** 
- Visual: Card
- Measure: `[Total PIQ Rotations]`
- Title: "PIQ Rotations"
- Color: #107C10 (Green)
- Format: Whole number, no decimals

**Card 3: Match Rate**
- Visual: Card  
- Measure: `[Match Rate %]`
- Title: "Match Rate"
- Color: #FF8C00 (Orange)
- Format: Percentage, 1 decimal

**Card 4: Data Quality Score**
- Visual: Card
- Measure: `[Data Quality Score]` 
- Title: "Data Quality"
- Color: #881798 (Purple)
- Format: Percentage, 1 decimal

### Middle Row - System Comparison

**Left: Source Counts by System (Clustered Column Chart)**
- Visual: Clustered Column Chart
- Axis: SOURCE_SYSTEM (from DASHBOARD-SOURCE-COUNTS)
- Legend: POPULATION (from DASHBOARD-SOURCE-COUNTS)
- Values: COUNT_ROTATION_BOOKINGS
- Colors: Custom - AIM=#D13438, NON-AIM=#0078D4, ALL=#605E5C
- Title: "Rotation Counts by System & Population"

**Right: Match Analysis (Donut Chart)**
- Visual: Donut Chart
- Legend: MATCH_TYPE (from DASHBOARD-MATCH-ANALYSIS)
- Values: COUNT_NON_AIM_ROTATIONS
- Colors: MATCHED=#107C10, ELENTRA_NO_MATCH=#FF8C00, PIQ_NO_MATCH=#D13438
- Title: "Match Analysis (Non-AIM Only)"

### Bottom Row - Unresolved Details

**Left: Elentra Unresolved Count**
- Visual: Card with drill-through button
- Measure: `[Elentra Unmatched]`
- Title: "Elentra Unmatched"
- Color: #FF8C00 (Orange)
- Drill-through: To "Elentra Details" page

**Right: PIQ Unresolved Count**
- Visual: Card with drill-through button  
- Measure: `[PIQ Unmatched]`
- Title: "PIQ Unmatched"
- Color: #D13438 (Red)
- Drill-through: To "PIQ Details" page

## Page 2: Elentra Details (Drill-Through)

**Single Table Visual (Full Page):**
- Visual: Table
- Columns from DASHBOARD-ELENTRA-UNRESOLVED:
  - MDCO_ENROLL_LRN_ROTATION_UID
  - MDCO_USR_UID  
  - ELENTRA_MDCODE
  - ELE_STARTDATE
  - ELE_ENDDATE
  - SITE_CODE
  - SCHEDULE_BLOCK
  - ENHANCED_MATCH_CATEGORY
- Title: "Elentra Unmatched Rotation Details"
- Enable: Export to Excel, Search, Column sorting

## Page 3: PIQ Details (Drill-Through)

**Single Table Visual (Full Page):**
- Visual: Table
- Columns from DASHBOARD-PIQ-UNRESOLVED:
  - MDCO_ENROLL_LRN_ROTATION_UID
  - PIQ_MDCO_USR_UID
  - PIQ_MDCO_COURSE_UID  
  - PIQ_STARTDATE
  - PIQ_ENDDATE
  - PIQ_MDCO_CAMPUS
  - ENHANCED_MATCH_CATEGORY
- Title: "PIQ Unmatched Rotation Details"  
- Enable: Export to Excel, Search, Column sorting

## Page 4: Data Quality Monitor

### Top: Deduplication Summary Table
- Visual: Table
- Columns from DASHBOARD-DEDUPLICATION-LOG:
  - TABLE_NAME
  - ORIGINAL_COUNT  
  - DEDUPLICATED_COUNT
  - DUPLICATES_REMOVED
  - DEDUP_PERCENTAGE
- Title: "Deduplication Impact by Table"
- Conditional formatting: DEDUP_PERCENTAGE (Red if >5%, Yellow if >1%, Green if ≤1%)

### Bottom Row: Quality Metrics
**Left: Duplicates Removed (Gauge)**
- Visual: Gauge  
- Value: `[Total Duplicates Removed]`
- Target: 0
- Title: "Total Duplicates Removed"

**Right: Overall Quality Score (Gauge)**
- Visual: Gauge
- Value: `[Data Quality Score]`
- Target: 1.0
- Title: "Overall Data Quality Score"

## Filters Configuration

### Page-Level Filters (Apply to All Pages):
- LAST_UPDATED (Date slider) - "Show data from:"
- SOURCE_SYSTEM (Dropdown) - "Filter by system:"

### Visual-Level Filters:
- **Non-AIM visuals**: Filter POPULATION ≠ "AIM"  
- **System comparison**: Show all populations for comparison

## Drill-Through Configuration

### From Main Dashboard to Detail Pages:
**Drill-through fields:**
- From Elentra Card → Pass: SOURCE_SYSTEM = "ELENTRA"
- From PIQ Card → Pass: SOURCE_SYSTEM = "PIQ"

**Enable drill-through icons on cards**

## Conditional Formatting Rules

### Cards:
- **Match Rate %**: Red if <60%, Yellow if 60-80%, Green if >80%
- **Data Quality**: Red if <80%, Yellow if 80-95%, Green if >95%

### Tables:
- **DEDUP_PERCENTAGE**: Data bars with red gradient
- **Count columns**: Data bars with blue gradient

## Mobile Layout (Optional)
- Stack cards vertically
- Single column layout
- Prioritize: Key metrics → Match analysis → Drill-through buttons

## Refresh Settings
- **Data refresh**: Every hour during business hours
- **Auto-refresh**: 15 minutes when viewing dashboard
- **Cache**: 30 minutes

This configuration gives you exact specifications to build in Power BI without any design decisions needed!