# Banner Zip File Processing - Power Automate Flow

## Overview
Automated Power Automate flow that processes Banner zip files dropped in SharePoint, extracts contents, renames with term identifiers, and moves to target directories.

## Flow Architecture

### **Trigger: SharePoint File Creation**
```
When a file is created (properties only)
├── Site Address: https://tamucs.sharepoint.com/teams/Team-vcom-oat-vdata-dev
├── Library Name: Shared Documents  
├── Folder Path: /banner-intake
└── File Type: .zip files only
```

### **Step 1: Get Zip File Properties**
```
Get file properties
├── Site Address: [Same as trigger]
├── Library Name: [Same as trigger]
├── File Identifier: [From trigger]
└── Extract: Name, Size, Created timestamp
```

### **Step 2: Extract Term Code from Filename**
```
Compose - Extract Term Code
├── Input: split(triggerOutputs()?['body/Name'], '_')[1]
├── Expected Format: "banner_202615_enrollment.zip" → "202615"
├── Fallback: Use creation date if parsing fails
└── Store in variable: TermCode
```

### **Step 3: Download Zip File Content**
```
Get file content
├── Site Address: [Same as trigger]  
├── Library Name: [Same as trigger]
├── File Identifier: [From trigger]
└── Output: Binary zip content
```

### **Step 4: Create Temporary Extraction Folder**
```
Create folder (SharePoint)
├── Site Address: [Same as trigger]
├── Library Name: Shared Documents
├── Folder Path: /banner-temp/[TermCode]-[timestamp]
└── Purpose: Temporary extraction location
```

## Unzip Process Options

### **Option A: Using Encodian Connector (Recommended)**
```
Encodian - Extract Archive
├── Archive: [Binary content from Step 3]
├── Extract To: [Temporary folder from Step 4]
├── Overwrite: Yes
└── File List Output: Available for processing
```

### **Option B: Manual Extraction Pattern** 
```
HTTP Request to Extract Service
├── Method: POST
├── URL: Custom unzip service endpoint
├── Body: Base64 encoded zip content
├── Headers: Content-Type: application/json
└── Response: List of extracted files
```

### **Option C: Azure Function Integration**
```
Azure Function - Unzip Service
├── Function URL: [Custom unzip function]
├── Method: POST  
├── Body: {"zipContent": "[base64]", "termCode": "[TermCode]"}
└── Returns: Array of extracted file information
```

## File Processing Pipeline

### **Step 5: Get Extracted Files**
```
Get files (properties only) 
├── Site Address: [Same as trigger]
├── Library Name: Shared Documents
├── Folder Path: /banner-temp/[TermCode]-[timestamp]
└── Output: List of extracted files
```

### **Step 6: Process Each Extracted File**
```
Apply to each (Extracted Files)
├── Input: [Files from Step 5]
├── Actions: File processing pipeline
└── Parallel Processing: Yes
```

#### **Sub-Step 6.1: Identify File Type**
```
Switch Control - File Type Detection
├── Input: items('Apply_to_each')?['Name']
├── Cases:
│   ├── contains(Name, 'enrollment') → Type: "enrollments"
│   ├── contains(Name, 'section') → Type: "sections"  
│   ├── contains(Name, 'course') → Type: "courses"
│   └── contains(Name, 'mapping') → Type: "mapping"
└── Default: "unknown"
```

#### **Sub-Step 6.2: Generate Target Filename**
```
Compose - Target Filename
├── enrollments.csv → [TermCode]/enrollments.csv
├── sections.csv → [TermCode]/sections.csv
├── courses.csv → [TermCode]/courses.csv  
└── mapping.csv → banner/VCOM-OAT-DATA-BANNER-CRSUID_map-master.csv
```

#### **Sub-Step 6.3: Copy to Target Location**
```
Copy file
├── Source Site: [Same as trigger]
├── Source Library: Shared Documents
├── Source Path: /banner-temp/[TermCode]-[timestamp]/[OriginalName]
├── Destination Site: [Same as trigger]
├── Destination Library: Shared Documents  
├── Destination Path: /banner/[TargetFilename]
└── Overwrite: Yes
```

### **Step 7: Cleanup Temporary Files**
```
Delete folder
├── Site Address: [Same as trigger]
├── Library Name: Shared Documents
├── Folder Path: /banner-temp/[TermCode]-[timestamp]
└── Purpose: Clean up extraction artifacts
```

### **Step 8: Move Processed Zip to Archive**
```
Move file
├── Source: /banner-intake/[ZipFileName]
├── Destination: /banner-processed/[TermCode]/[ZipFileName]
├── Overwrite: Yes
└── Purpose: Archive processed zip files
```

### **Step 9: Send Completion Notification**
```
Send email (Optional)
├── To: Data team distribution list
├── Subject: "Banner [TermCode] files processed successfully"
├── Body: Processing summary with file counts and timestamps
└── Attachments: Processing log (optional)
```

## SharePoint Folder Structure

```
/banner-intake/          # Drop zone for zip files
/banner-temp/            # Temporary extraction (auto-cleanup)
/banner-processed/       # Archive of processed zip files
│   ├── 202515/         # Term-specific archive folders
│   ├── 202615/
│   └── 202715/
/banner/                 # Target directory for extracted files  
│   ├── 202515/         # Term-specific data folders
│   │   ├── enrollments.csv
│   │   ├── sections.csv
│   │   └── courses.csv
│   ├── 202615/
│   │   ├── enrollments.csv  
│   │   ├── sections.csv
│   │   └── courses.csv
│   └── VCOM-OAT-DATA-BANNER-CRSUID_map-master.csv  # Shared mapping
```

## Error Handling

### **Step 10: Error Handling Scope**
```
Scope - Try Block
├── Contains: Steps 1-8 (main processing)
├── Configure run after: Success only
└── Timeout: 30 minutes
```

### **Step 11: Error Recovery**
```
Scope - Catch Block  
├── Configure run after: Failed, Skipped, Timed out
├── Actions:
│   ├── Send error notification email
│   ├── Log error details to SharePoint list
│   ├── Move zip file to /banner-errors/ folder
│   └── Clean up any partial extractions
```

## Advanced Features

### **Step 12: Processing Validation**
```
HTTP Request - Validate Extracted Files
├── URL: Custom validation endpoint
├── Method: POST
├── Body: List of extracted files with term code
├── Response: Validation results
└── Action: Send alerts if validation fails
```

### **Step 13: Audit Log Creation**
```
Create item (SharePoint List)
├── List: Banner Processing Audit
├── Fields:
│   ├── TermCode: [Extracted term code]
│   ├── ZipFileName: [Original zip name]
│   ├── ProcessingDate: [Current timestamp]
│   ├── FilesProcessed: [Count of extracted files]
│   ├── Status: "Success" or "Failed"
│   └── ErrorDetails: [If any errors occurred]
```

## Flow Configuration

### **Trigger Settings**
```json
{
  "type": "SharePointFileTrigger",
  "settings": {
    "site": "https://tamucs.sharepoint.com/teams/Team-vcom-oat-vdata-dev",
    "library": "Shared Documents",
    "folder": "/banner-intake",
    "fileFilter": "*.zip",
    "triggerOnPropertiesChange": false
  }
}
```

### **Parallel Processing Configuration**
```json
{
  "concurrency": {
    "runs": 1,
    "maximumWaitingRuns": 10
  },
  "runtimeConfiguration": {
    "lifetime": {
      "durationInHours": 2
    }
  }
}
```

## Benefits

1. **Fully Automated**: No manual intervention required
2. **Term Aware**: Automatically extracts term codes and organizes files
3. **Overwrite Safe**: Replaces existing files as requested
4. **Error Resilient**: Comprehensive error handling and cleanup
5. **Audit Trail**: Complete processing history and validation
6. **Scalable**: Handles multiple zip files and parallel processing

## Implementation Steps

1. **Create SharePoint folder structure** as outlined above
2. **Configure Power Automate flow** with appropriate connectors
3. **Set up Encodian connector** (or custom unzip solution)
4. **Test with sample zip files** to validate processing
5. **Configure notification and error handling** email addresses
6. **Deploy to production** with appropriate permissions

This flow will automatically handle your Banner zip file processing requirements, extracting to the correct term-specific folders and overwriting existing files as needed!