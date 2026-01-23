
Token        = "VCOM OAT" | Domain | System | Artifact | Env | Qual;
Domain       = "VCAT" | "VSTU" | "VENROLL" | "VEVAL" | "VDATA" | "VSITE" | "VFACU";
System       = "TBANNER" | "VELENTRA" | "VPIQ" | "VFACPORT";
Env          = "DEV" | "TEST" | "UAT" | "PROD" | "SBX";
Direction    = "INBOUND" | "OUTBOUND";
Date         = YYYY MM DD;    (* compact: YYYYMMDD as a single token *)
Time         = HH MM;         (* 24-hour: HHMM as a single token *)
Version      = "v" Digit {Digit};
Artifact     = <short, kebab/pascal, platform-specific>;
Qual         = Direction | Date | Time | Version | <purpose>;

# Display names use: "Section | Section | Section"
# Path/URL names use: "section-section-section"
