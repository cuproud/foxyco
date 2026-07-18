# FoxyCo - Claude Code Project Instructions

## Project Overview

FoxyCo is a Flutter application focused on intelligent ride offer analysis, parsing, filtering, and user assistance workflows.

This project is actively developed using Claude Code.

The project contains:
- Flutter mobile application
- Offer parsing logic
- Overlay/bubble UI components
- Settings management
- Device-related integrations
- Analysis and filtering workflows


# Core Development Rules

Before making any code changes:

1. Understand the existing architecture first.
2. Use codebase-memory-mcp before searching broadly.
3. Identify:
   - affected classes
   - callers
   - dependencies
   - data flow
   - related widgets/services

Do not create new patterns if an existing pattern already exists.

Prefer improving existing implementations over introducing duplicate logic.


# Codebase Exploration Rules

Preferred order:

1. Query codebase-memory-mcp
2. Search using ripgrep
3. Read relevant files
4. Modify code

Before modifying a class:

Check:
- Who calls it?
- What depends on it?
- Is there existing similar functionality?


# Flutter Architecture Guidelines

Follow the existing project architecture.

General rules:

- Keep business logic separated from UI.
- Avoid putting complex logic directly inside widgets.
- Reuse existing services, providers, repositories, and utilities.
- Avoid unnecessary widget rebuilds.
- Prefer clean, maintainable Dart code.

When adding new features:

First explain:
- affected files
- architecture impact
- possible risks

Then implement.


# State Management

Follow the existing state management approach already used in the project.

Do not introduce a new state management library or pattern without explicit approval.

Before changing state logic:
- identify providers/controllers/services involved
- understand current data flow


# UI Development Rules

For UI changes:

- Preserve existing design language.
- Reuse existing widgets/components.
- Avoid unnecessary redesign.
- Maintain responsive layouts.

For overlay/bubble features:
- consider lifecycle behavior
- device compatibility
- performance impact


# Parsing / Analysis Logic

Parsing and analysis features are critical.

Before modifying:

Understand:
- input flow
- parsing stages
- filtering rules
- scoring/decision logic
- output handling

Avoid breaking existing parsing behavior.


# Existing Development History

Important previous work is documented in:

.claude/sessions/

and:

.claude/completions/


Review relevant documents before modifying related areas.

Important sessions:

- Overlay and device verification:
  .claude/sessions/HANDOFF-2026-07-13-m3-device-verified.md

- Parsing and overlay rework:
  .claude/sessions/HANDOFF-2026-07-12-m3-parsing-overlay-rework.md

- Parse and tap design:
  .claude/sessions/DESIGN-2026-07-13-parse-and-tap.md


# Project Documentation

Important folders:

## lib/

Main Flutter application source.

## assets/

Images and application resources.

## docs/

Project documentation.

## references/

External references and research material.

## third_party/

External code.

Do not modify third_party unless explicitly required.


# Dependency Changes

Before adding dependencies:

Explain:
- why the package is needed
- alternatives considered
- maintenance impact

Avoid unnecessary packages.


# Testing Requirements

After significant changes:

Run:

flutter analyze

and relevant tests:

flutter test


Before considering a task complete:

Confirm:
- no analyzer errors
- no obvious regressions
- build compatibility


# Build Environment

Primary environment:

- Flutter
- Dart
- Android
- Ubuntu WSL2 development environment


# Git Practices

Before large changes:

Review:

git status

Keep commits focused.

Avoid:
- committing generated files
- unnecessary build artifacts
- unrelated formatting changes


# Claude Code Behavior

When working on this project:

- Think before editing.
- Explain important architectural decisions.
- Prefer small incremental changes.
- Avoid blindly rewriting working code.
- Preserve existing functionality.

Use available tools:

- codebase-memory-mcp for architecture understanding
- Headroom for efficient context handling
- TokenSave for token optimization


# Completion Checklist

Before finishing a task:

1. Confirm requested functionality is implemented.
2. Check affected files.
3. Run validation where possible.
4. Summarize:
   - files changed
   - behavior changed
   - tests performed
   - possible follow-ups
