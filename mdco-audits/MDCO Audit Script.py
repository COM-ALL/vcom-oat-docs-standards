
import pandas as pd

# -------------------------------------------------------------------
# 1. CONFIG: update these file names as needed
# -------------------------------------------------------------------
MDCO_FILE   = "VCOM-OAT-DATA-MDCO-CRSUID-v3.csv"
BANNER_FILE = "VCOM-OAT-DATA-BANNER-CRSUID_map-v3.csv"
ELENTRA_FILE= "VCOM-OAT-DATA-ELENTRA-CRSUID-v3.csv"
PIQ_FILE    = "VCOM-OAT-DATA-PIQ-CRSUID_map-v3.csv"

# -------------------------------------------------------------------
# 2. LOAD FILES
# -------------------------------------------------------------------
mdco    = pd.read_csv(MDCO_FILE)
banner  = pd.read_csv(BANNER_FILE)
elentra = pd.read_csv(ELENTRA_FILE)
piq     = pd.read_csv(PIQ_FILE)

issues = []  # all issues will be collected here as dicts

# -------------------------------------------------------------------
# 3. HELPERS
# -------------------------------------------------------------------
def normalize_mdcode(code):
    """
    Normalize MDCODE like 'IMED 844' -> 'IMED844'
    Works for 'MEID 103', 'MFCM 839', etc.
    """
    if pd.isna(code):
        return ""
    return "".join(str(code).split())

# -------------------------------------------------------------------
# 4. MDCO keymap internal consistency checks
#    - UID-NAME prefix
#    - MDCODE in UID vs MDCO-COURSE-MDCODE
# -------------------------------------------------------------------
for idx, row in mdco.iterrows():
    uid      = str(row.get("MDCO-COURSE-UID", ""))
    uid_name = str(row.get("MDCO-COURSE-UID-NAME", ""))
    mdcode   = row.get("MDCO-COURSE-MDCODE", "")
    ref      = row.get("ref-num", "")

    # 4a. MDCO-COURSE-UID-NAME prefix rule
    if not uid_name.startswith(uid + ":"):
        issues.append({
            "ref-num": ref,
            "table": "MDCO-CRSUID",
            "issue": "MDCO-COURSE-UID-NAME does not start with MDCO-COURSE-UID + ':'",
            "MDCO-COURSE-UID": uid,
            "MDCO-COURSE-UID-NAME": uid_name,
        })

    # 4b. MDCODE consistency: body of UID vs MDCO-COURSE-MDCODE
    if uid.startswith("MDCO-"):
        body = uid.split("MDCO-")[1]
        # Use substring before last '.' as MDCODE portion
        base = body[: body.rfind(".")] if "." in body else body
        norm_md = normalize_mdcode(mdcode)
        if base != norm_md:
            issues.append({
                "ref-num": ref,
                "table": "MDCO-CRSUID",
                "issue": "MDCODE in MDCO-COURSE-UID does not match MDCO-COURSE-MDCODE",
                "MDCO-COURSE-UID": uid,
                "MDCO-COURSE-MDCODE": mdcode,
                "base_from_UID": base,
                "normalized_MDCODE": norm_md,
            })

# -------------------------------------------------------------------
# 5. Ensure all MDCO-COURSE-UIDs in mapping tables exist in MDCO keymap
# -------------------------------------------------------------------
valid_uids = set(mdco["MDCO-COURSE-UID"].astype(str))

def check_mapping(df, ref_col, table_name):
    for idx, row in df.iterrows():
        ref = row.get(ref_col, "")
        uid = str(row.get("MDCO-COURSE-UID", ""))
        if uid not in valid_uids:
            issues.append({
                "ref-num": ref,
                "table": table_name,
                "issue": "MDCO-COURSE-UID not found in MDCO CRSUID keymap",
                "MDCO-COURSE-UID": uid,
            })

check_mapping(banner,  "ref-num", "BANNER-CRSUID_map")
check_mapping(elentra, "ref-num", "ELENTRA-CRSUID")
check_mapping(piq,     "crs-ref", "PIQ-CRSUID_map")

# -------------------------------------------------------------------
# 6. Check for duplicate mappings:
#    Same external-id (course ID) → different MDCO-COURSE-UIDs
#    across BANNER, ELENTRA, and PIQ
# -------------------------------------------------------------------
rows = []
# BANNER
for _, r in banner.iterrows():
    rows.append({
        "source": "BANNER",
        "ref-num": r["ref-num"],
        "external-id": r["BANNER-COURSE-UID"],
        "MDCO-COURSE-UID": r["MDCO-COURSE-UID"],
    })
# ELENTRA
for _, r in elentra.iterrows():
    rows.append({
        "source": "ELENTRA",
        "ref-num": r["ref-num"],
        "external-id": r["ELENTRA-COURSE-UID"],
        "MDCO-COURSE-UID": r["MDCO-COURSE-UID"],
    })
# PIQ
for _, r in piq.iterrows():
    rows.append({
        "source": "PIQ",
        "ref-num": r["crs-ref"],
        "external-id": r["PIQ-COURSE-UID"],
        "MDCO-COURSE-UID": r["MDCO-COURSE-UID"],
    })

all_map = pd.DataFrame(rows)

for ext, grp in all_map.groupby("external-id"):
    if grp["MDCO-COURSE-UID"].nunique() > 1:
        for _, row in grp.iterrows():
            issues.append({
                "ref-num": row["ref-num"],
                "table": row["source"],
                "issue": "Same external course-id mapped to multiple MDCO-COURSE-UID values across systems",
                "external-id": ext,
                "MDCO-COURSE-UID": row["MDCO-COURSE-UID"],
            })

# -------------------------------------------------------------------
# 7. PIQ: MDCO_...COURSECAT... should start with MDCO-COURSE-UID + '-'
# -------------------------------------------------------------------
cat_col = None
for c in piq.columns:
    # Handle both MDCO_COURSECAT_UID-SITE and MDCO-COURSECAT-UIDxSITE-style names
    if "COURSECAT" in c.upper():
        cat_col = c
        break

if cat_col:
    for idx, row in piq.iterrows():
        ref = row.get("crs-ref", "")
        uid = str(row.get("MDCO-COURSE-UID", ""))
        site = row.get(cat_col, "")
        if pd.isna(site):
            continue
        site_str = str(site).strip()
        if site_str == "" or site_str.upper() == "N/A":
            continue
        expected_prefix = uid + "-"
        if not site_str.startswith(expected_prefix):
            issues.append({
                "ref-num": ref,
                "table": "PIQ-CRSUID_map",
                "issue": f"{cat_col} does not start with MDCO-COURSE-UID + '-'",
                "MDCO-COURSE-UID": uid,
                cat_col: site_str,
            })

# -------------------------------------------------------------------
# 8. Print results
# -------------------------------------------------------------------
if not issues:
    print("✅ No MDCO audit issues found. All checks passed.")
else:
    print(f"⚠️ Found {len(issues)} issue(s). Showing all below:\n")
    issues_df = pd.DataFrame(issues)
    # Order columns for readability
    cols = ["table", "ref-num", "issue", "external-id", "MDCO-COURSE-UID",
            "MDCO-COURSE-MDCODE", "base_from_UID", "normalized_MDCODE"]
    # Keep only columns that actually exist in this run
    cols = [c for c in cols if c in issues_df.columns]
    print(issues_df[cols].to_string(index=False))
