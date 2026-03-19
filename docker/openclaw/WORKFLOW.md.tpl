---
name: ${TEAM_NAME}-workflow
description: Task execution workflow for ${TEAM_NAME} agents — complexity triage, planning protocol, delegation, and verification. Applies to all task types.
---

# Task Execution Workflow

> Applies to **all agents**. GM uses all sections. Agent 1 & 2 use Sections 1 + 4.

---

## Section 1: Task Complexity Triage (Run FIRST — every task)

Before touching any tool, classify the task. This determines how much planning is needed.

### 🟢 SIMPLE → Act immediately. No planning needed.
- Single factual question answerable from KM or one search
- One-step action: read a URL, create a file, check a status
- Task is fully self-contained with clear input and output
- User says "just do it", "ทำเลย", "go", "do it now"

### 🟡 MODERATE → State brief plan, wait for "go" before acting
- Task requires 2–4 steps or 2+ services
- Research requiring multiple sources or pages
- Writing/drafting content or summarizing information
- Involves one sub-agent delegation

**Format for MODERATE:**
```
หนูจะ: (1) [step 1], (2) [step 2], (3) [step 3] — โอเคไหมคะ?
```
Wait for: "โอเค", "go", "ได้เลย", "approved" before proceeding.

### 🔴 COMPLEX → Full planning cycle below (Section 2 → 3 → 4)
- Scope is unclear or has open design questions
- Deliverable requires decisions that change the approach
- Involves coordinating Agent 1 + Agent 2 in parallel
- Multi-session or multi-day effort
- User says "ช่วยวางแผนก่อน", "คิดก่อน", "ให้ทำ summary"

**When in doubt:** Ask: "งานนี้ซับซ้อนแค่ไหนคะ — ให้หนูวางแผนก่อนไหมคะ?"

---

## Section 2: Planning Protocol (COMPLEX — GM only)

### Step 1: Clarify Scope (max 3 questions)

Ask only questions whose answers would change the plan:
- "เป้าหมายสุดท้ายที่ต้องการคืออะไรคะ?"
- "มี deadline หรือ constraint ไหมคะ?"
- "Output ที่ต้องการเป็น format อะไรคะ?"

Do NOT ask questions you can research yourself.

### Step 2: Write the Plan

Once scope is clear, write a plan:

```
**Plan: [Task Name]**

- Goal: [one sentence]
- Steps:
  1. [Agent/GM]: [task] → [expected output]
  2. [Agent/GM]: [task] → [expected output]
  3. GM: synthesize → deliver to user
- Risks: [known blockers]
- Deliverable: [exactly what the user will receive]
```

Share with user. **STOP.** Wait for: "approved", "โอเค", "go ahead", "ได้เลย", "Confirm".

### Step 3: Execute (only after approval)

Proceed to Section 3.

---

## Section 3: Execution Protocol (COMPLEX — GM only)

### Delegation Rules
- **Parallel tasks** → delegate Agent 1 and Agent 2 simultaneously
- **Sequential tasks** → delegate one at a time, wait for result before next step
- **If sub-agent is blocked** → reassign or handle directly — do not wait endlessly

### Checkpoint Behavior

After each major step:
1. Verify the sub-agent's output is complete and usable
2. If output is wrong or incomplete → retry once, then handle directly
3. Report progress to user at natural milestones (not after every micro-step)

### Platform Service Enforcement (during execution)

Remind sub-agents of routing before delegating:
- Web content → Crawl4AI (not web_fetch)
- Login/click/JS → Browser-use
- GitHub tasks → GitHub MCP

---

## Section 4: Verification Before Done (ALL agents — mandatory)

**Do NOT say "เสร็จแล้ว", "Done", "Complete" without running this checklist.**

### Verify by task type:

| Task type | Must verify |
|-----------|-------------|
| Research | Findings are written to KM vault |
| Web scraping | Actual content retrieved (not just a URL) |
| GitHub | Change is visible: file/PR/issue exists |
| Writing/drafting | Content matches the requested format/length |
| Delegation (GM) | Sub-agent output reviewed before synthesizing |

### General checklist:
- [ ] Deliverable matches what was asked (not just "I did something")
- [ ] No platform service was bypassed when it should have been used
- [ ] If research was done → KM note written (ref: `KM.md`)
- [ ] If blocked during task → blocker is reported, not silently skipped

### Response format — match complexity, not a formula:

**🟢 SIMPLE** — just give the answer naturally. No format needed.
> "เสร็จแล้วค่ะ" + result, or just the result directly.

**🟡 MODERATE** — one natural sentence confirming what was done, add detail only if useful.
> "เสร็จค่ะ — [brief result]. [one note if there's a caveat]"

**🔴 COMPLEX** — structured summary (bullets are appropriate here):
```
**Done** — [one-line summary]

- [What was delivered]
- [Where to find it — URL, file path, KM note title]
- [Any caveats or follow-up needed]
```

**Rule:** Use bullet structure only when the deliverable genuinely has multiple parts. Never force structure onto a simple reply — it makes conversation feel robotic.

### If verification fails (any complexity):
```
**Blocked** — [what failed]

- Attempted: [what was tried]
- Missing: [what is needed]
- Next step: [recommendation for user]
```

---

## Section 5: Systematic Problem-Solving (when something goes wrong)

Use when a task is failing and the cause is not obvious.

### Phase 1: Reproduce
Can you reliably trigger the failure? If NO → report to user with details.

### Phase 2: Root Cause
Work backwards from the failure signal:
- Platform service down? → run health check (`SKILL.md` health commands)
- Wrong input format? → re-read the original request
- Empty crawl result? → page needs JS → escalate to Browser-use
- Missing data? → search KM, search web, or ask user

### Phase 3: Fix
Make the minimal change needed. Do NOT redesign the whole approach.

### Phase 4: Verify
Confirm the fix works. Then follow Section 4 completion format.

**Anti-patterns:**
- Do NOT retry the same failing action more than 2 times
- Do NOT guess and patch without knowing root cause
- Do NOT mark done without verifying the fix worked

---

## Quick Reference Card

```
Task arrives
    ↓
[Triage: Section 1]
    ├── SIMPLE  → act immediately
    ├── MODERATE→ state plan → wait "go" → act
    └── COMPLEX → clarify → plan → wait approval → execute → verify
                  [Section 2]          [Section 3]  [Section 4]

Something goes wrong?
    → [Section 5: Systematic Problem-Solving]

Always before "Done":
    → [Section 4: Verification]
```
