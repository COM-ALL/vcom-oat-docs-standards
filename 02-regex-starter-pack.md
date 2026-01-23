
# GitHub repo: vcom-oat-<family>-<domain>(-<system>)?(-<purpose>)?
^vcom-oat-(docs|pm|code|data)-(vcat|vstu|venroll|veval|vdata|vsite|vfacu)(-(tbanner|velentra|vpiq|vfacport))?(-[a-z0-9-]+)?$

# SharePoint CSVs (example for inbound/outbound):
^(TBANNER|VELENTRA|VPIQ|VFACPORT)_[a-z0-9]+_(INBOUND|OUTBOUND)_\d{8}(_\d{4})?(_v\d+)?\.csv$

# Power Automate flow display:
^VCOM OAT \| (VCAT|VSTU|VENROLL|VEVAL|VDATA|VSITE|VFACU) \| [A-Za-z]+( [A-Za-z]+)* \| (TBANNER|VELENTRA|VPIQ|VFACPORT)? \| (DEV|TEST|UAT|PROD)$
