# Power Platform / Power BI Dataflow Naming Standard

```
Generate a Power Platform or Power BI Dataflow name using the VCOM OAT naming standard. 
Follow these rules:

Display names use Title Case with " | " separators.  
Format:
"VCOM OAT | <Domain> | <System> | <Dataset> | <INBOUND or OUTBOUND> | <ENV>"

Internal/technical name (if needed):
"vcom_<domain>_<system>_<dataset>_<direction>_<env>" in lower_snake_case.

Valid tokens:
Domains: VCAT, VSTU, VENROLL, VEVAL, VDATA, VSITE, VFACU  
Systems: TBANNER, VELENTRA, VPIQ, VFACPORT  
Directions: INBOUND, OUTBOUND  
Environments: DEV, TEST, UAT, PROD

Given:
• Domain: <insert domain>
• System: <insert system>
• Dataset: <insert dataset>
• Direction: INBOUND or OUTBOUND
• Environment: <insert env>

Produce:
1. Dataflow Display Name  
2. Dataflow Internal Name
```
