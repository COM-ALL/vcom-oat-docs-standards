# VCOM-OAT-COURSE-CATALOG DATASET
---------------------------------------

SOURCES OF TRUTH FOR COURSE CATALOG UID MAPPINGS


## ORIGIN TABLES

### Environment URL

````
org4c96263d.crm.dynamics.com
````
### TABLES

SYSTEM | TABLE
------ | -------
MDCO | cr026_vcomoatdatamdcocrsuid_mapkey
ELENTRA | cr026_vcomoatdataelentracrsuid_map
PROGRESSIQ | cr026_vcomoatdatapiqcrsuid_map

-----------------
## FABRIC DATAFLOWS

### All tables are updated by

dfg2_VCOM OAT CRSCAT UPDATE (CRSCAT UPATE)

QUERIES

````
1. [VCOM-OAT-DATA-BANNER-CRSUID_map](VCOM-OAT-DATA-BANNER-CRSUID_map.pq)
2. [VCOM-OAT-DATA-ELENTRA-CRSUID_map](VCOM-OAT-DATA-ELENTRA-CRSUID_map.pq)
3. [VCOM-OAT-DATA-MDCO-CRSUID_mapkey](VCOM-OAT-DATA-MDCO-CRSUID_mapkey.pq)
4. []()

````

### TASK MANAGERS

1. Get data

-----------------

## DBO TABLES

### VCOM-OAT-DATA-PIQ-CRSUID_map

column headers:
````
PIQ-CATUID
MDCO-COURSE-UID
mdco_PIQxELE-CATUIDSITEUID
MDCO_CAMPUSUID
vcomoatdatapiqcrsuid_mapid
````

### VCOM-OAT-DATA-ELENTRA-CRSUID_map

column headers:
````
ELENTRA-CATUID
MDCO-COURSE-UID
````

### VCOM-OAT-DATA-ELENTRA-CRSUID_map

column headers:
````
ELENTRA-CATUID
MDCO-COURSE-UID
````

### VCOM-OAT-DATA-MDCO-CRSUID_mapkey

column headers:
````
MDCO_COURSE_UID
MDCO_MDCODE
MDCO_COURSECAT_UID
MDCO_COURSENAME
MDCO_COURSE-CATEGORY
````

### VCOM-OAT-DATA-BANNER-CRSUID_map

column headers:
````
BANNER-CATUID
MDCO-COURSE-UID
````