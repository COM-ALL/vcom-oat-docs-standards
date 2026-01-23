# Power Platform (Power Apps + Dataverse + Power Automate)

## Environments (Display Name)

Pattern (Title Case):

```
VCOM OAT | <Purpose/Scope> | <ENV>
```
***Examples:***

```
VCOM OAT | Academic Data Platform | DEV
VCOM OAT | Academic Data Platform | PROD
```

## Unique (internal) environment name (safe snake case):

```
vcom_oat_<scope>_<env>     # e.g., vcom_oat_acad_data_platform_dev
```

## Solutions
Display Name (Title Case with pipes):

```
VCOM OAT | <Domain> | <System?> | <Capability> | <ENV>
```

***Examples:***

```
VCOM OAT | VDATA | VELENTRA | User Sync | DEV
VCOM OAT | VENROLL | TBANNER | Course Feeds | PROD
```

### Solution Name (internal)

```
vcom_<domain>_<system?>_<capability>_<env>
# e.g., vcom_vdata_velentra_user_sync_dev
```

Publisher prefix: vcom (configure once; all table/column logical names inherit this)