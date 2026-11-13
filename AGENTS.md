# Rules
- Do only what I explicitly ask. No extra actions, files, refactors, or commands.
- If a request is ambiguous or touches anything not asked for, stop and ask.
- Never write to external services (Figma, git remotes, deploys) or install/delete anything without my confirmation.
- Never automate git push. Do NOT run `git push` automatically. Always keep commits local unless explicitly instructed to push in that specific request, or ask for confirmation first.
- spec/ is the source of truth. Read spec/*.md before any task.
- Status labels: build only [Locked]. For [Draft], propose or stub only. For [Open] or unlabeled, ask me.
- Never invent requirements. If the spec is unclear or contradicts itself, stop and ask.
- Work from one file in spec/changes/ at a time; stay inside its Tasks and Out of scope.
- If code and spec disagree, tell me. Don't silently pick one.
- Don't edit main spec/ files unless running /merge-change.
- Tiny tweaks (text, color, spacing; one file, no behavior change) may be done directly on request.
- File naming convention: Always use PascalCase and no numbers for code files (e.g., `PrimaryButton.swift`, `RollViewModel.swift`; no numbers like `View2.swift` or `ButtonV1.swift`).
- Dead code cleanup: When executing an approved change or refactor, remove obsolete, unused, or superseded functions, properties, and logic that are no longer relevant, provided removing them is verified non-breaking (all references removed, tests compile and pass). Do not leave commented-out code or unused dead methods behind. (If deleting an entire file, ask for confirmation first or specify it in the change file tasks to protect Xcode project references).
- After any task, report what you did and what you did not do.

# Rule for write a code
## 1. Think Before Coding

**Don't assume. Don't hide confusion. Surface tradeoffs.**

Before implementing:
- State your assumptions explicitly. If uncertain, ask.
- If multiple interpretations exist, present them - don't pick silently.
- If a simpler approach exists, say so. Push back when warranted.
- If something is unclear, stop. Name what's confusing. Ask.

## 2. Simplicity First

**Minimum code that solves the problem. Nothing speculative.**

- No features beyond what was asked.
- No abstractions for single-use code.
- No "flexibility" or "configurability" that wasn't requested.
- No error handling for impossible scenarios.
- If you write 200 lines and it could be 50, rewrite it.

Ask yourself: "Would a senior engineer say this is overcomplicated?" If yes, simplify.

## 3. Surgical Changes

**Touch only what you must. Clean up only your own mess.**

When editing existing code:
- Don't "improve" adjacent code, comments, or formatting.
- Don't refactor things that aren't broken.
- Match existing style, even if you'd do it differently.
- If you notice unrelated dead code, mention it - don't delete it.

When your changes create orphans:
- Remove imports/variables/functions that YOUR changes made unused.
- Don't remove pre-existing dead code unless asked.

The test: Every changed line should trace directly to the user's request.

## 4. Goal-Driven Execution

**Define success criteria. Loop until verified.**

Transform tasks into verifiable goals:
- "Add validation" → "Write tests for invalid inputs, then make them pass"
- "Fix the bug" → "Write a test that reproduces it, then make it pass"
- "Refactor X" → "Ensure tests pass before and after"

For multi-step tasks, state a brief plan:
```
1. [Step] → verify: [check]
2. [Step] → verify: [check]
3. [Step] → verify: [check]
```

Strong success criteria let you loop independently. Weak criteria ("make it work") require constant clarification.
