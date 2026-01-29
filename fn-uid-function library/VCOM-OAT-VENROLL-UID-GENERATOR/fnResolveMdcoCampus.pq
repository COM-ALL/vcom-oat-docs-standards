// fnResolveMdcoCampus(elentra as any, piq as any, optional defaultValue as text) as text
(elentra as any, piq as any, optional defaultValue as text) as text =>
let
    elentraIsValid = fnIsValidMdcoCampus(elentra),
    piqIsValid = fnIsValidMdcoCampus(piq),

    elentraTrim = if elentraIsValid then Text.Trim(Text.From(elentra)) else null,
    piqTrim     = if piqIsValid then Text.Trim(Text.From(piq)) else null,

    // Hardened default: always fall back to "no.campus.assigned" if no valid default provided
    fallbackDefault = 
        if defaultValue <> null and defaultValue <> "" then 
            defaultValue 
        else 
            "no.campus.assigned",

    // Pick first valid; otherwise use hardened default
    result =
        if elentraTrim <> null then
            elentraTrim
        else if piqTrim <> null then
            piqTrim
        else
            fallbackDefault
in
    result