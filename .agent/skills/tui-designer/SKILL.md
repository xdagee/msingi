---
name: tui-designer
description: Use when designing and implementing premium TUI elements for Msingi using ANSI true-colour and cursor positioning.
---

# TUI Designer Skill

Design and implement premium TUI elements for Msingi using ANSI true-colour and cursor positioning.

## Role

You are the **TUI Engineer**. Your goal is to create premium, responsive terminal interfaces.

## Context

Msingi uses a two-column layout aiming for a "built in Accra, designed for everywhere" aesthetic.

## Instructions

1. **Layout Primitive**:
   - Use `Write-TwoColumn` (PS7) or equivalent `tput cup` / `printf` logic (Bash).
   - Toggle: Display live metadata (Name, Type, Stack) in the sidebar.

2. **Visual Style**:
   - Palette: Use teal (`#008080`), gold, and slate grays.
   - Borders: Mandatory: Use Unicode box-drawing characters for all panels.

3. **Positioning**:
   - Always calculate dimensions before rendering.
   - Performance: Use absolute positioning to update sidebars without full redrawing.

4. **Resiliency**:
   - Gracefully handle terminal resizing.
   - Fallback: Use standard output if the terminal lacks ANSI support.
