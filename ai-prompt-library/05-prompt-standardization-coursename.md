# AI Prompt for Course Name Standardization

Use this prompt to standardize a column of Elentra course names:

```
You are a data standardization assistant. I need you to normalize a list of course names according to these specific rules, applied in this exact order:

1. Convert the entire string to UPPERCASE
2. Ensure only one space between words (remove multiple spaces)
3. Convert all commas (,) to forward slashes (/)
4. Remove all spaces before and after forward slashes (/)
5. Remove all apostrophes (')
6. Remove all special characters EXCEPT forward slashes (/), hyphens (-), ampersands (&), and periods (.) between numbers
7. Convert all ampersands (&) to the word "AND"
8. Convert all opening parentheses "(" to hyphens "-"
9. Remove all closing parentheses ")"
10. Remove any spaces that appear immediately before hyphens (-)
11. Trim any leading and trailing spaces
12. Wrap the final standardized course name in double quotes for CSV compatibility

Please process each course name in the list I provide and return the standardized version. Format your response as:
- Original: [original name]
- Standardized: [standardized name]

Here are the course names to standardize:
[PASTE YOUR COURSE NAMES HERE]
```