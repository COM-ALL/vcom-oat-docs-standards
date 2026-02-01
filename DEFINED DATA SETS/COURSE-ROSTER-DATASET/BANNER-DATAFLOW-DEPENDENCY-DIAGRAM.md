# BANNER DATAFLOW DEPENDENCY DIAGRAM
**MDCO_ENROLL_BANNER_COURSE_ROSTERS_IN**

## CRITICAL MDCO MATCHING CONCERN
⚠️ **User Issue**: Final MDCO matching logic vs CRN-based approach needs review  
⚠️ **Table Update Verification**: Ensure `OAT-DATA-BANNER-CATALOG-CRN` is being updated properly

---

## QUERY GROUP STRUCTURE

```
📊 ENROLLMENT GROUP (3 queries)
├── banner_202615_enrollments
├── banner_202535_enrollments  
└── banner_202515_enrollments

📊 SECTIONS GROUP (3 queries)
├── banner_202615_sections
├── banner_202535_sections
└── banner_202515_sections

📊 COURSES GROUP (3 queries)  
├── banner_202615_courses
├── banner_202535_courses
└── banner_202515_courses

📊 COURSES_NORMALIZED GROUP (4 queries)
├── banner-courses-tobe normalized
├── banner-courses-normalize-standard
├── banner-courses-normalize-cc shells
└── banner-courses-normalize-meid989

📊 SUPPORT GROUP (4 queries)
├── CLEAN_CourseNames_No989
├── banner-sections-202515-202615
├── banner-courses-202515-202615  
└── OAT-DATA-BANNER-CATALOG-CRN
```

---

## DEPENDENCY FLOW DIAGRAM

### LEVEL 1: SharePoint Sources
```
[SP] banner_202615_enrollments ─┐
[SP] banner_202535_enrollments ─┼─→ LEVEL 2
[SP] banner_202515_enrollments ─┘

[SP] banner_202615_sections ────┐
[SP] banner_202535_sections ────┼─→ LEVEL 2  
[SP] banner_202515_sections ────┘

[SP] banner_202615_courses ─────┐
[SP] banner_202535_courses ─────┼─→ LEVEL 2
[SP] banner_202515_courses ─────┘
```

### LEVEL 2: Term Consolidation
```
[3 enrollment sources] ─→ MDCO-ENROLL-BANNER-COURSE-ROSTER (main output)
[3 sections sources]   ─→ banner-sections-202515-202615
[3 courses sources]    ─→ banner-courses-tobe normalized
```

### LEVEL 3: Course Normalization Pipeline
```
banner-courses-tobe normalized ─┬─→ banner-courses-normalize-standard
                                ├─→ banner-courses-normalize-cc shells  
                                └─→ banner-courses-normalize-meid989

CLEAN_CourseNames_No989 ←───────┴─ banner-courses-tobe normalized
                        │
                        ├─→ banner-courses-normalize-standard
                        ├─→ banner-courses-normalize-cc shells
                        └─→ banner-courses-normalize-meid989
```

### LEVEL 4: Final Course Consolidation
```
banner-courses-normalize-standard ─┐
banner-courses-normalize-cc shells ─┼─→ banner-courses-202515-202615
banner-courses-normalize-meid989 ───┘
```

### LEVEL 5: CRITICAL MATCHING LAYER ⚠️
```
banner-sections-202515-202615 ←─── banner-courses-202515-202615 (course lookup)
                             │
                             ├─── [LAKEHOUSE] OAT-DATA-BANNER-CATALOG-CRN (CRN→MDCO mapping)
                             │
                             └─→ MDCO-ENROLL-BANNER-COURSE-ROSTER (FINAL)
```

---

## CRITICAL DATA PATHS TO VERIFY

### 🔍 **PRIMARY CONCERN: MDCO Course UID Resolution**

**Current Flow:**
1. `banner-sections-202515-202615` joins with `banner-courses-202515-202615` on `canv_sectname`
2. Then joins with `OAT-DATA-BANNER-CATALOG-CRN` on `{term, ban_CRN}` 
3. **MDCO_COURSE_UID comes from lakehouse table**: `OAT-DATA-BANNER-CATALOG-CRN`

**Key Questions:**
- ❓ Is `OAT-DATA-BANNER-CATALOG-CRN` lakehouse table current?
- ❓ Does CRN-based matching provide cleaner results than course name matching?
- ❓ Are there enrollment records with missing MDCO_COURSE_UID due to lookup failures?

### 🔍 **SharePoint File Dependencies**
```
/datafiles/inbound/banner/
├── banner-202615-processed/
│   ├── 20260131-143022-banner_202615_enrollments.csv
│   ├── 20260131-143022-banner_202615_sections.csv
│   └── 20260131-143022-banner_202615_courses.csv
├── banner-202535-processed/  
│   ├── 20260131-143022-banner_202535_enrollments.csv
│   ├── 20260131-143022-banner_202535_sections.csv
│   └── 20260131-143022-banner_202535_courses.csv
└── banner-202515-processed/
    ├── 20260131-143022-banner_202515_enrollments.csv
    ├── 20260131-143022-banner_202515_sections.csv
    └── 20260131-143022-banner_202515_courses.csv
```

---

## FINAL OUTPUT SCHEMA
**MDCO-ENROLL-BANNER-COURSE-ROSTER** produces:
- `MDCO_COURSE_UID` ← **FROM LAKEHOUSE LOOKUP** ⚠️
- `course_id`, `section_id`, `user_id`  
- `role`, `status`, `term`
- `ban_CRN`, `ban_DEPT`, `ban_CRSNUM`, `ban_SECTNUM`, `ban_COURSENAME`

---

## RECOMMENDED INVESTIGATION STEPS

1. **Verify Lakehouse Table Currency**
   ```sql
   -- Check OAT-DATA-BANNER-CATALOG-CRN update frequency
   -- Verify term coverage: 202515, 202535, 202615
   ```

2. **Audit MDCO Matching Success Rate** 
   ```powerquery
   // Count null MDCO_COURSE_UID in final output
   // Compare CRN vs course name matching accuracy
   ```

3. **Trace Course Name Normalization**
   - Standard courses → `CLEAN_CourseNames_No989` lookup
   - CC shells → Section expansion logic  
   - MEID.989 → Special parsing from long_name

4. **Validate CRN-Based Alternative**
   - Direct CRN→MDCO mapping vs multi-step course name approach
   - Performance and accuracy comparison

---

## ARCHITECTURE NOTES

- **Query Groups**: Well-organized logical separation
- **Term Handling**: Properly processes all 3 current terms 
- **Course Types**: Handles standard, combined course shells, and MEID.989 special cases
- **Final Matching**: **Two-step lookup** (course name → CRN → MDCO) may be redundant

**💡 SUGGESTION**: Consider direct CRN→MDCO lookup to simplify and improve accuracy