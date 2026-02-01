# Banner CSV File Processing - Power Automate Flow (No Unzip)

## Overview
Automated Power Automate flow that processes Banner CSV files dropped individually in SharePoint, identifies file types and terms, and organizes them into target directories.

## Flow Architecture

### **Trigger: SharePoint File Creation**
```
When a file is created (properties only)
├── Site Address: https://tamucs.sharepoint.com/teams/Team-vcom-oat-vdata-dev
├── Library Name: data-files  
├── Folder Path: /inbound/banner/intake
├── File Type: .csv files only
└── Filter: File extension equals ".csv"
```

### **Step 1: Get CSV File Properties**
```
Get file properties
├── Site Address: [Same as trigger]
├── Library Name: [Same as trigger]
├── File Identifier: [From trigger]
└── Extract: Name, Size, Created timestamp, Full path
```

### **Step 2: Extract Term Code and File Type**
```
Compose - Parse Filename
├── Input: triggerOutputs()?['body/Name']
├── Expected Formats:
│   ├── "banner_202615_enrollments.csv" → Term: 202615, Type: enrollments
│   ├── "202615_sections.csv" → Term: 202615, Type: sections
│   ├── "courses_202615.csv" → Term: 202615, Type: courses
│   └── "mapping_master.csv" → Term: SHARED, Type: mapping
└── Parse Logic: Extract 6-digit term code (20XXYY format)
```

### **Step 3: Initialize Variables**
```
Initialize Variables:
├── TermCode (String): Extracted 6-digit term from filename
├── FileType (String): enrollments|sections|courses|mapping
├── TargetFolder (String): Target directory path
└── NewFileName (String): Standardized filename
```

### **Step 4: Determine File Type and Target**
```
Switch Control - File Type Detection
├── Input: File name analysis
├── Cases:
│   ├── contains(Name, 'enrollment') → 
│   │   ├── FileType: "enrollments"
│   │   ├── NewFileName: "enrollments.csv"
│   │   └── TargetFolder: "/inbound/banner/[TermCode]/"
│   ├── contains(Name, 'section') → 
│   │   ├── FileType: "sections"  
│   │   ├── NewFileName: "sections.csv"
│   │   └── TargetFolder: "/inbound/banner/[TermCode]/"
│   ├── contains(Name, 'course') → 
│   │   ├── FileType: "courses"
│   │   ├── NewFileName: "courses.csv"  
│   │   └── TargetFolder: "/inbound/banner/[TermCode]/"
│   └── contains(Name, 'mapping') → 
│       ├── FileType: "mapping"
│       ├── NewFileName: "VCOM-OAT-DATA-BANNER-CRSUID_map-master.csv"
│       └── TargetFolder: "/inbound/banner/"
└── Default: Move to /banner-errors/ for manual review
```

### **Step 5: Create Target Term Folder (If Needed)**
```
Create folder (SharePoint) - Term Folder
├── Site Address: [Same as trigger]
├── Library Name: data-files
├── Folder Path: /inbound/banner/[TermCode]
├── Condition: Only if FileType ≠ "mapping"
└── Configure run after: Success, Failed (folder may exist)
```

### **Step 6: Copy File to Target Location**
```
Copy file
├── Source Site: [Same as trigger]
├── Source Library: data-files
├── Source Path: /inbound/banner/intake/[OriginalFileName]
├── Destination Site: [Same as trigger]
├── Destination Library: data-files  
├── Destination Path: [TargetFolder]/[NewFileName]
└── Overwrite: Yes
```

### **Step 7: Move Processed CSV to Archive**
```
Move file
├── Source: /inbound/banner/intake/[OriginalFileName]
├── Destination: /inbound/banner/processed/[TermCode]/[timestamp]-[OriginalFileName]
├── Create folder if needed: Yes
└── Purpose: Archive processed CSV files with original names
```

### **Step 8: Validate File Placement**
```
Get file properties - Validation
├── Site Address: [Same as trigger]
├── Library Name: data-files
├── File Path: [TargetFolder]/[NewFileName]
├── Purpose: Confirm file was placed correctly
└── Store result for audit logging
```

### **Step 9: Send Processing Notification**
```
Send email (Optional)
├── To: Data team distribution list
├── Subject: "Banner [FileType] file processed for term [TermCode]"
├── Body: 
│   ├── Original filename: [OriginalFileName]
│   ├── New location: [TargetFolder]/[NewFileName]
│   ├── File size: [Size]
│   └── Processing timestamp: [Current time]
```

## SharePoint Folder Structure

```
/inbound/banner/intake/       # Drop zone for individual CSV files
/inbound/banner/processed/    # Archive of processed CSV files
│   ├── 202515/              # Term-specific archive folders
│   │   ├── 20260131-143022-banner_202515_enrollments.csv
│   │   ├── 20260131-143045-sections_202515.csv
│   │   └── 20260131-143108-courses202515.csv
│   └── 202615/
│       ├── 20260131-150212-enrollment_spring2026.csv
│       └── 20260131-150234-202615sections.csv
/inbound/banner/              # Target directory for organized files  
│   ├── 202515/              # Fall 2025 term folder
│   │   ├── enrollments.csv
│   │   ├── sections.csv
│   │   └── courses.csv
│   ├── 202615/              # Spring 2026 term folder
│   │   ├── enrollments.csv  
│   │   ├── sections.csv
│   │   └── courses.csv
│   └── VCOM-OAT-DATA-BANNER-CRSUID_map-master.csv  # Fourth file (shared mapping)
```

## Filename Pattern Recognition

### **Term Code Extraction Logic**
```javascript
// Extract 6-digit term code from various filename patterns
function extractTermCode(filename) {
    // Pattern 1: banner_202615_enrollments.csv → 202615
    let match1 = filename.match(/(\d{6})/);
    
    // Pattern 2: Look for 20XXYY format specifically  
    let match2 = filename.match(/(20\d{4})/);
    
    // Pattern 3: Spring/Fall year mapping
    let match3 = filename.match(/(spring|fall)(\d{4})/i);
    
    return match1?.[1] || match2?.[1] || deriveFromSeason(match3);
}
```

### **File Type Detection Logic**
```javascript
// Identify file type from filename
function identifyFileType(filename) {
    let name = filename.toLowerCase();
    
    if (name.includes('enroll')) return 'enrollments';
    if (name.includes('section')) return 'sections';  
    if (name.includes('course')) return 'courses';
    if (name.includes('mapping') || name.includes('uid')) return 'mapping';
    
    return 'unknown';
}
```

## Error Handling

### **Step 10: Error Processing Scope**
```
Scope - Try Block
├── Contains: Steps 1-8 (main processing)
├── Configure run after: Success only
└── Timeout: 10 minutes
```

### **Step 11: Error Recovery**
```
Scope - Catch Block  
├── Configure run after: Failed, Skipped, Timed out
├── Actions:
│   ├── Move file to /banner-errors/ folder
│   ├── Send error notification email with file details
│   ├── Log error to SharePoint audit list
│   └── Include original filename and error details
```

### **Step 12: Unknown File Handling**
```
Condition - File Type = "unknown"
├── True Branch:
│   ├── Move to /banner-manual-review/
│   ├── Send notification to admin
│   └── Log for manual classification
└── False Branch: Continue normal processing
```

## Advanced Processing

### **Step 13: File Content Validation**
```
HTTP Request - Quick Validation
├── URL: Custom validation endpoint (optional)
├── Method: POST
├── Body: {
│     "fileType": "[FileType]",
│     "termCode": "[TermCode]", 
│     "filePath": "[TargetPath]"
│   }
├── Response: Validation status
└── Action: Alert if validation fails
```

### **Step 14: Audit Log Creation**
```
Create item (SharePoint List) - Banner CSV Processing Log
├── List: Banner CSV Processing Audit
├── Fields:
│   ├── OriginalFileName: [From trigger]
│   ├── TermCode: [Extracted term]
│   ├── FileType: [Identified type]
│   ├── TargetLocation: [Final file path]
│   ├── ProcessingDate: [Current timestamp]
│   ├── FileSize: [In bytes]
│   ├── Status: "Success" | "Failed" | "Manual Review"
│   └── ErrorDetails: [If any errors occurred]
```

## Flow Configuration

### **Trigger Settings - CSV Files Only**
```json
{
  "type": "SharePointFileTrigger",
  "settings": {
    "site": "https://tamucs.sharepoint.com/teams/Team-vcom-oat-vdata-dev",
    "library": "data-files",
    "folder": "/inbound/banner/intake",
    "fileFilter": "*.csv",
    "triggerOnPropertiesChange": false,
    "triggerOnContentChange": false
  }
}
```

### **Parallel Processing Prevention**
```json
{
  "concurrency": {
    "runs": 1,
    "maximumWaitingRuns": 50
  }
}
```

## Usage Workflow

### **Step 1: Drop CSV Files**
User drops individual CSV files into `/inbound/banner/intake/`:
- `banner_202615_enrollments.csv`
- `sections_spring_2026.csv` 
- `202615_courses.csv`
- `mapping_update_jan2026.csv`

### **Step 2: Automatic Processing**
Flow processes each file:
- Extracts term code: `202615`
- Identifies file types: `enrollments`, `sections`, `courses`, `mapping`
- Creates term folder: `/inbound/banner/202615/`
- Renames and moves files to standard locations

### **Step 3: Final State**
Files organized for Power Query consumption:
```
/inbound/banner/202615/enrollments.csv
/inbound/banner/202615/sections.csv  
/inbound/banner/202615/courses.csv
/inbound/banner/VCOM-OAT-DATA-BANNER-CRSUID_map-master.csv
```

## Benefits

1. **Flexible Input**: Handles various filename patterns
2. **Term Organization**: Automatically organizes by term
3. **Overwrite Safe**: Replaces existing files as needed
4. **Archive Preservation**: Keeps original files with timestamps
5. **Error Recovery**: Handles unknown files gracefully
6. **Fourth File Support**: Mapping file available at banner root
7. **Audit Trail**: Complete processing history

This simplified flow removes all zip complexity while maintaining the same organizational structure for your Power Query integration!