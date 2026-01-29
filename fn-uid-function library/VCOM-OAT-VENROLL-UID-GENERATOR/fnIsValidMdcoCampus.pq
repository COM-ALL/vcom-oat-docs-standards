// fnIsValidMdcoCampus(x as any) as logical
(x as any) as logical =>
let
    // Must be text
    isText = Value.Is(x, type text),
    t = if isText then Text.Trim(x) else null,
    // valid if text starts with "vcom." (case-insensitive)
    isValid = if t = null or t = "" then false else Text.StartsWith(Text.Lower(t), "vcom.")
in
    isValid