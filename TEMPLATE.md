---
name: skill-name-here
description: One-paragraph trigger statement. Agents read this to decide whether to invoke the skill, so be precise about WHEN to use it. Mention the kinds of tasks, keywords, or situations that should activate it. Avoid vague phrases like "useful for various tasks".
license: MIT
metadata:
  author: joaohenriques
  version: "0.1.0"
---

# Skill Name Here

One- or two-sentence description of what this skill does. This is for humans skimming the file.

## When to use

- Concrete trigger 1 (e.g., "user asks to design a new feature")
- Concrete trigger 2
- Concrete trigger 3

## When NOT to use

- Counter-example 1 (helps the agent avoid over-applying the skill)
- Counter-example 2

## Instructions

The actual skill content. Markdown, code blocks, links — whatever helps the agent execute well.

Keep it focused. Prefer one clear procedure over many alternatives.

## Example

A short worked example showing the skill in action.

---

<!--
Authoring notes (delete before committing):

1. Folder name == frontmatter `name`. Use kebab-case.
2. Skill names must be unique across ALL domains (install.sh enforces this).
3. The `description` is the most important field — it's what gets matched against user intent.
4. Supporting files (scripts, references, examples) can live alongside this SKILL.md in the same folder.
5. Bump `metadata.version` when you make breaking changes to the skill's contract.
-->
