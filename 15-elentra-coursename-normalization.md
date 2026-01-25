# Elentra Course Name Normalization Rules

Apply these standardization rules to normalize CRSTITLE values:

## Normalization Rules

1. **Convert to uppercase**
   - Before: `Introduction to Biology`
   - After: `INTRODUCTION TO BIOLOGY`

2. **Ensure only one space between words**
   - Before: `MOLECULAR    BIOLOGY     BASICS`
   - After: `MOLECULAR BIOLOGY BASICS`

3. **Convert commas to forward slashes**
   - Before: `FOX, TROT`
   - After: `FOX/TROT`

4. **Remove spaces before and after forward slashes**
   - Before: `FOX / TROT`
   - After: `FOX/TROT`
   - Before: `ANATOMY /PHYSIOLOGY`
   - After: `ANATOMY/PHYSIOLOGY`

5. **Remove apostrophes**
   - Before: `FOX'S ANATOMY`
   - After: `FOXS ANATOMY`

6. **Remove special characters (except '/', '-', '&', and '.' between numbers)**
    - Before: `JAZZ!`
    - After: `JAZZ`
    - Before: `CHEMISTRY@BASICS`
    - After: `CHEMISTRYBASICS`
    - Before: `COURSE 3.5 CREDITS`
    - After: `COURSE 3.5 CREDITS`

7. **Convert ampersands to 'AND'**
   - Before: `R&B MUSIC`
   - After: `R AND B MUSIC`

8. **Convert opening parentheses to hyphens and remove closing parentheses**
   - Before: `FOX TROT (DANCE)`
   - After: `FOX TROT-DANCE`
   - Before: `BIOLOGY (ADVANCED TOPICS)`
   - After: `BIOLOGY-ADVANCED TOPICS`

9. **Remove spaces before hyphens**
   - Before: `ADVANCED -BIOLOGY`
   - After: `ADVANCED-BIOLOGY`

10. **Trim leading and trailing spaces**
    - Before: `  MOLECULAR BIOLOGY  `
    - After: `MOLECULAR BIOLOGY`

11. **Wrap CRSTITLE values in double quotes for CSV export**
    - Before: `GASTROINTESTINAL/METABOLISM AND NUTRITION`
    - After: `"GASTROINTESTINAL/METABOLISM AND NUTRITION"`
    - Purpose: Ensures proper CSV formatting when course titles contain commas or other special characters

## Complete Example

**Before:** `  Introduction to Biology & Chemistry (Advanced Topics), Part 1  `

**After:** `INTRODUCTION TO BIOLOGY AND CHEMISTRY-ADVANCED TOPICS/PART 1`

## AI Prompt for Course Name Standardization

Reference the AI prompt in [05-prompt-standardization-coursename.md](05-prompt-standardization-coursename.md) for automating this normalization process.
