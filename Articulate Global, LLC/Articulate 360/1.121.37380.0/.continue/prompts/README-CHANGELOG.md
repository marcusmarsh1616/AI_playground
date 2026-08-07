---
name: README and CHANGELOG Builder
description: Generate README.md and CHANGELOG.md for a deployment script.
invokable: true
---

I need you to generate two Markdown files for my deployment script:

1. README.md
2. CHANGELOG.md

Use the following formatting rules:

- If you see a `.git` folder in the current directory, attempt to pull all current committed changes.
- If a `README.md` already exists, evaluate if the data is pertinent to the package and include that info in the new `README.md`.
- If a second file titled `Startup.pss` is provided, assume that to be the template to determine changes.
- If only 1 file is provided and there is no `.git` folder, assume this is an initial creation.

**`README.md` REQUIREMENTS**
- Begin with the "Internal_FR/Official_Use" badge exactly like this:
  `https://img.shields.io/badge/Internal_FR/Official_Use-00475b`
- Title: Product or Script Name (I will provide name)
- Sections must include:
  • Description
  • Key Capabilities
  • Deployment Groups - Add a bullet for Intune SME group but leave it blank for future completion
  • Changelog (just link to CHANGELOG.md)
  • Notes
- Write in a professional but concise style.
- Description should summarize what the script or application does.
- Key Capabilities should list major functions or responsibilities.
- Notes should describe important usage context or enterprise limitations. Bulletize the list.

**`CHANGELOG.md` REQUIREMENTS**
- Begin with the same badge:
  `https://img.shields.io/badge/Internal_FR/Official_Use-00475b`
- Title: Product or Script Name + "Release Notes"
- For each version (I will provide version number):
  Include:
  * Version header with current date
  * "Change Notes" section
- Only use the following bullet points for the structure if a change occurs there outside of the standard template:
  * Beginning
  * Variables
  * Pre-Install
  * Install
  * Post-Install
  * Pre-Uninstall
  * Uninstall
  * Post-Uninstall
  * End
- Keep the tone similar to vendor release notes (e.g., VMware / Omnissa style).

**INPUTS I WILL PROVIDE**
- Script or product name IF not provided in script
- Current version IF not provided in script
- Optional Comments
- Date

**OUTPUT FORMAT**
Provide:
1. Complete `README.md`
2. Complete `CHANGELOG.md`

Both fully formatted using Markdown, no placeholders left behind unless I specify placeholders. Each file should be created individually.

Do not summarize or explain details after preparing files.