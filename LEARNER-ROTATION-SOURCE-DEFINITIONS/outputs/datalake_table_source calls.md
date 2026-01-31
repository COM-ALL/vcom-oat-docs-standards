# LEARNER ROTATION DATA LAKE SOURCE CALLS

## MDCO-ENROLL-ELENTRA-COURSE-ROSTER-ACTIVE

````
let
  Source = Lakehouse.Contents(null),
  Navigation = Source{[workspaceId = "c9e4d5a1-d250-42a1-a864-5acd524511e1"]}[Data],
  #"Navigation 1" = Navigation{[lakehouseId = "fa80ccb4-153e-4730-80c1-9fab4f3dbd4d"]}[Data],
  #"Navigation 2" = #"Navigation 1"{[Id = "MDCO-ENROLL-ELENTRA-COURSE-ROSTER-ACTIVE", ItemKind = "Table"]}[Data]
in
  #"Navigation 2"
````
## MDCO-ENROLL-ELENTRA-ROTATIONS-ACTIVE

```
let
  Source = Lakehouse.Contents(null),
  Navigation = Source{[workspaceId = "c9e4d5a1-d250-42a1-a864-5acd524511e1"]}[Data],
  #"Navigation 1" = Navigation{[lakehouseId = "fa80ccb4-153e-4730-80c1-9fab4f3dbd4d"]}[Data],
  #"Navigation 2" = #"Navigation 1"{[Id = "MDCO-ENROLL-ELENTRA-ROTATIONS-ACTIVE", ItemKind = "Table"]}[Data]
in
  #"Navigation 2"
```

## MDCO-ENROLL-ELENTRA-ROTATIONS-AIM

```
let
  Source = Lakehouse.Contents(null),
  Navigation = Source{[workspaceId = "c9e4d5a1-d250-42a1-a864-5acd524511e1"]}[Data],
  #"Navigation 1" = Navigation{[lakehouseId = "fa80ccb4-153e-4730-80c1-9fab4f3dbd4d"]}[Data],
  #"Navigation 2" = #"Navigation 1"{[Id = "MDCO-ENROLL-ELENTRA-ROTATIONS-AIM", ItemKind = "Table"]}[Data]
in
  #"Navigation 2"
```

## MDCO-ENROLL-ELENTRA-ROTATIONS-AIM

```
  let
  Source = Lakehouse.Contents(null),
  Navigation = Source{[workspaceId = "c9e4d5a1-d250-42a1-a864-5acd524511e1"]}[Data],
  #"Navigation 1" = Navigation{[lakehouseId = "fa80ccb4-153e-4730-80c1-9fab4f3dbd4d"]}[Data],
  #"Navigation 2" = #"Navigation 1"{[Id = "MDCO-ENROLL-PIQ-ROTATIONS-AIM", ItemKind = "Table"]}[Data]
in
  #"Navigation 2"
```

## MDCO-ENROLL-PIQ-ROTATION-SCHEDULED

```
let
Source = Lakehouse.Contents(null),
Navigation = Source{[workspaceId = "c9e4d5a1-d250-42a1-a864-5acd524511e1"]}[Data],
#"Navigation 1" = Navigation{[lakehouseId = "fa80ccb4-153e-4730-80c1-9fab4f3dbd4d"]}[Data],
#"Navigation 2" = #"Navigation 1"{[Id = "MDCO-ENROLL-PIQ-ROTATION-SCHEDULED", ItemKind = "Table"]}[Data]
in
  #"Navigation 2"
```

## MDCO-ENROLL-ROTATIONS-UTILITY

```
    let
  Source = Lakehouse.Contents(null),
  Navigation = Source{[workspaceId = "c9e4d5a1-d250-42a1-a864-5acd524511e1"]}[Data],
  #"Navigation 1" = Navigation{[lakehouseId = "fa80ccb4-153e-4730-80c1-9fab4f3dbd4d"]}[Data],
  #"Navigation 2" = #"Navigation 1"{[Id = "MDCO-ENROLL-ROTATIONS-UTILITY", ItemKind = "Table"]}[Data]
in
  #"Navigation 2"
```