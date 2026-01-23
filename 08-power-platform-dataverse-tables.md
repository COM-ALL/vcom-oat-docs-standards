# Dataverse Tables

Display Name: Title Case singular → plural handled by Dataverse
e.g., Elentra User, Elentra Users

Logical (schema) name:

```
vcom_<bounded_noun>_s
# e.g., vcom_elentra_user_s, vcom_course_s, vcom_enrollment_s
```
Columns (logical): vcom_<table>_<attribute> (short)
e.g., vcom_user_elentra_id, vcom_enrollment_status

Keep logical names short, lowercase, no spaces; display names can be friendly.