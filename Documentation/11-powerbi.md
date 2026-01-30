# Power BI (workspaces, datasets, reports, semantic models)

Workspace Display Name:

```
VCOM OAT | <Domain> | <Purpose> | <ENV> [<Sensitivity?>]
# Example: VCOM OAT | VDATA | Ops Dashboards | PROD [Internal]
```

## Artifacts inside a workspace:

Semantic model (dataset): 

```
VCOM OAT – <Domain> – <Subject> – <ENV>
```
Report: 

```
VCOM OAT – <Domain> – <Subject> – <Audience> – <ENV>
```
Dataflow (if using Power BI dataflows):

```
VCOM OAT – <Domain> – <System> – <Dataset> – <Direction> – <ENV>
```

Use en-dashes (–) or hyphens consistently; avoid colons in names that flow into file paths.