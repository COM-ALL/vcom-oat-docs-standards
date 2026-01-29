// fnResolveMdcoCampus(elentra as any, piq as any) as text
(elentra as any, piq as any) as text =>
let
    elentraIsValid = fnIsValidMdcoCampus(elentra),
    piqIsValid = fnIsValidMdcoCampus(piq),

    elentraTrim = if elentraIsValid then Text.Trim(Text.From(elentra)) else null,
    piqTrim     = if piqIsValid then Text.Trim(Text.From(piq)) else null,

    // Pick first valid; otherwise default
    result =
        if elentraTrim = null then
            (if piqTrim = null then "no.campus.assigned" else piqTrim)
        else
            elentraTrim
in
    result