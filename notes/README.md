# Subject Notes Guide

This project now uses a subject-first notes workflow based on **Notion HTML exports**.

## Folder Structure

```text
notes/
|-- README.md
|-- subjects.config.json
`-- content/
    |-- machine-learning-ai/
    |   |-- Unit 1/
    |   |   |-- Unit 1 - AML ....html
    |   |   `-- exported images
    |   |-- Unit 2/
    |   |-- UNIT 3/
    |   `-- Unit 4/
    `-- your-next-subject/
        `-- Topic Folder/
            |-- Exported Page.html
            `-- exported images
```

## User Workflow

1. The user clicks `Notes` in the main navbar.
2. They land on `notes.html`.
3. They choose a subject from the subject grid.
4. The left panel shows the **topic folders** inside that subject.
5. Clicking a topic loads the exported HTML note in the right panel.

## Your Workflow For Adding New Notes

### Add a new topic to an existing subject

1. Export the Notion page as **HTML**.
2. Put the exported folder inside the correct subject folder, for example:

```text
notes/content/machine-learning-ai/Unit 5/
```

3. Make sure the folder contains the exported `.html` file and its assets.
4. Run:

```powershell
& "H:\portfolio\scripts\build-notes-data.ps1"
```

5. Commit the updated files and push to GitHub.

### Add a new subject

1. Create a new folder inside:

```text
notes/content/<new-subject-slug>/
```

Example:

```text
notes/content/data-mining/
```

2. Add one or more exported topic folders inside it.
3. Open [subjects.config.json](/H:/portfolio/notes/subjects.config.json:1) and add the display name and description:

```json
{
  "subjects": {
    "data-mining": {
      "name": "Data Mining",
      "description": "Patterns, methods, and analytical concepts for data mining."
    }
  }
}
```

4. Run:

```powershell
& "H:\portfolio\scripts\build-notes-data.ps1"
```

5. Commit and push.

## Template For A New Subject

Use this structure:

```text
notes/content/<subject-slug>/
    <Topic Folder 1>/
        Exported Page.html
        assets...
    <Topic Folder 2>/
        Exported Page.html
        assets...
```

Example:

```text
notes/content/python-programming/
    Unit 1/
        Python Basics.html
        images...
    Unit 2/
        Functions and OOP.html
        images...
```

## Important Note About GitHub

GitHub Pages is a static site, so the browser cannot automatically read your folder tree live.

That is why this project uses:

- `notes/subjects.config.json` for subject labels and descriptions
- `scripts/build-notes-data.ps1` to scan your actual folders and generate:
  [notes-data.js](/H:/portfolio/assets/js/notes-data.js:1)

That generated file is what the website reads after you push.
