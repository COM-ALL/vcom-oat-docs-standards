🧱 The 3-Part Strategy for Persistent Knowledge Across Chats
1. Put reusable facts, functions, and definitions into notebook cells
Examples:
A Markdown cell labeled:
# 📚 Function Library (Persistent Across Chats)

Inside it you store:

A list of Power Query functions you defined
Where they live (which Dataflow Gen2)
The purpose of each function
Any business rules or mapping schemas
Your UID definitions (RotationUID, CRSRosterUID)
File paths or SharePoint folder structures
Table schemas
“Lookup table definitions”
Anything you expect future chats to reference

You can even create sections like:
## Normalization Functions
- fnNormalizeStudentId
- fnNormalizeRotationCourseCode
- fnNormalizeText
- fnWeekKeyFromDate

Or even paste the actual M code:
Power Query// Persisted function referencelet fnNormalizeStudentId = ...Show more lines
Copilot can read these cells in any new chat within the notebook.

2. Give the collection a clear section header
Copilot inside notebooks responds really well to labeled sections such as:
# Reference Library for VCOM OAT | VDATA | Lakehouse | DEV

Or:
## UID Generator Functions – Authoritative Version

That way, when you say in a new chat:

“Use the function definitions in the UID Generator section above.”

Copilot will automatically pull from that notebook content.

3. In each new chat, explicitly tell Copilot to reference the Notebook Section
Example prompt in the new chat:

“For this chat, please reference the section titled UID Generator Functions – Authoritative Version above in this notebook.
Use the functions listed there (fnRotationUID, fnNormalizeStudentId, etc.) when generating Power Query or Dataflow patterns.”

Now Copilot has access to:

The function names
Their definitions (if you included them)
Your business logic
Your pipeline structure
Your preferred naming conventions

Even though the chat itself is fresh.

🧠 Why this works so well
Copilot inside Fabric notebooks:

Can read the notebook content
Cannot remember previous chats
Does not persist conversation history
But does persist notebook cells

This means:

You control what persists
You decide what’s reusable
You can intentionally curate a “living library”
Nothing gets tangled between unrelated chats

It’s actually a very elegant pattern when used intentionally.