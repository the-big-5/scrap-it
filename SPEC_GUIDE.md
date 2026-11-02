# How to Work with AI Agents on ScrapIt

This project uses a spec-driven workflow to keep AI agents (Antigravity, Cursor, Claude Code, etc.) strictly aligned with what we want, preventing unwanted code changes, rogue refactors, or hallucinated features.

---

## The Core Rule

> **The agent must never guess, assume, or write code without explicit permission.**
> The `spec/` folder is the single source of truth. Code is only written through **Approved Change Files**.

---

## 1. The Status System (Traffic Light)

Every section in `spec/*.md` has a status tag that tells the agent what it is permitted to do:

| Status | Meaning | What the Agent Can Do |
| :--- | :--- | :--- |
| **`[Locked]`** | Decided & verified | **Build it.** Full green light to implement. |
| **`[Draft]`** | Proposed / in progress | **Propose or stub only.** Cannot be treated as final. |
| **`[Open]`** (or unlabeled) | Undecided | **Stop and ask.** Forbidden from guessing or inventing details. |

---

## 2. The 3-Step Lifecycle for Features & Changes

Whenever you want the agent to build or change something, follow this loop:

```
1. /new-change  ──►  2. Human Approval  ──►  3. /implement-change  ──►  4. /merge-change
   (Draft file)         (Status: Approved)       (Agent builds it)         (Archive & sync)
```

### Step 1: Draft the Change (`/new-change`)
1. In the chat, type `/new-change` and describe what you want in plain words.
2. The agent will ask clarifying questions.
3. The agent creates a new file: `spec/changes/00X-<title>.md` with `Status: Proposed`.
4. **The agent touches ZERO code during this step.**

### Step 2: The Human Checkpoint (You Approve)
1. Open `spec/changes/00X-<title>.md`.
2. Review:
   - Are the **Tasks** accurate?
   - Is **Out of scope** clearly defined?
3. When you are satisfied, edit line 2 of the file:
   ```markdown
   Status: Approved
   ```
   *(This is the gate: the agent is instructed never to execute an unapproved change).*

### Step 3: Implement the Change (`/implement-change 00X`)
1. In chat, run:
   ```text
   /implement-change 00X
   ```
   *(e.g., `/implement-change 001`)*
2. The agent will:
   - Check that `Status: Approved` is present.
   - Build **only** the items listed in `## Tasks` in order.
   - Strictly honor `## Out of scope`.
   - Report what was completed and what could not be done.

### Step 4: Sync & Archive (`/merge-change 00X`)
1. Once tested and verified working in Xcode:
   ```text
   /merge-change 00X
   ```
2. The agent updates the main specs (`spec/flows.md`, `spec/tech.md`, `spec/ui.md`), marks the change `Done`, and moves the file to `spec/changes/archive/`.

---

## 3. Quick Bug Fixes & Tiny Tweaks

To avoid heavy process for small items:
* **Allowed directly:** Single-file edits (fixing a typo, minor padding, color tweaks) with no architectural, data model, or flow impact.
* **Requires a change file:** Anything touching data models, state flows, multi-screen navigation, backend/CloudKit, or app logic.

---

## 4. Copy-Paste Starter Prompt for New Agent Sessions

When starting a new conversation with an AI agent in this repo, send this prompt:

```text
Please read AGENTS.md and spec/*.md before doing anything.
Respect all [Locked], [Draft], and [Open] labels.
Do not write any code unless executing an approved change file from spec/changes/.
```

---

## File Structure Overview

```text
ScrapIt/
├── AGENTS.md               # Standing rules the agent reads every session
├── SPEC_GUIDE.md           # This guide for human collaborators
├── .agents/
│   └── workflows/          # Slash command definitions
│       ├── new-change.md
│       ├── implement-change.md
│       └── merge-change.md
├── spec/
│   ├── product.md          # Concept, goals, non-goals, open questions
│   ├── flows.md            # User flows (F1, F2, F3...)
│   ├── tech.md             # Stack, architecture, models, boundaries
│   ├── ui.md               # Screens, component states, Figma links
│   └── changes/            # Active change files (e.g. 001-capture-session.md)
│       ├── TEMPLATE.md
│       └── archive/        # Completed change files
└── ScrapIt/                # iOS Swift source code
```
