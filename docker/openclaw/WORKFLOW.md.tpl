---
name: ${TEAM_NAME}-workflow
description: Task execution workflow for ${TEAM_NAME} agents — complexity triage, GitHub Projects board integration, planning, delegation, and verification.
---

# Task Execution Workflow

> **ALL agents** use Section 1 (Triage) and Section 5 (Verification).
> **Workers (Tom, Jerry)** also use Section 3 (Board task execution).
> **GM (Spike) only** uses Sections 2 + 4 (Planning + Delegation).

---

## Section 1: Task Complexity Triage (Run FIRST — every task)

Classify BEFORE touching any tool. This determines planning overhead and whether to open a board task.

### 🟢 SIMPLE → Act immediately. No board. No planning.

**Qualifiers (ALL must be true):**
- Quick Q&A, single factual answer, or one-step action
- Completable in under ~5 minutes with one tool call
- No deliverable that needs tracking or review
- User says "ทำเลย", "go", "แค่นี้", "do it now"

**→ Just do it. No issue. No board. Respond directly.**

---

### 🟡 MODERATE → Open board task → work → close

**Qualifiers (any one is enough):**
- Requires 2–4 steps or 2+ platform services
- Research with multiple sources or pages
- Writing/drafting any content (blog post, brief, outline, analysis)
- Effort estimated > 10 minutes
- Output that Boom or Spike might want to reference later

**→ Open GitHub issue first → work → comment result → close (Section 3)**

---

### 🔴 COMPLEX → Open board task + full plan → delegate → track → verify

**Qualifiers (any one is enough):**
- Multi-session or multi-day effort
- Requires Tom AND Jerry working in parallel
- Scope is unclear or has open design decisions
- Outcome affects other tasks or team direction
- User says "ช่วยวางแผนก่อน", "คิดก่อน", "summary ให้หน่อย"

**→ Full cycle: Section 2 (Plan) → Section 3 (Execute) → Section 4 (Delegate) → Section 5 (Verify)**

---

> **When in doubt:** Classify as MODERATE. A board task costs 30 seconds. Missing context costs hours.

---

## Section 2: Planning Protocol (🔴 COMPLEX — GM only)

### Step 1: Clarify Scope (max 3 questions)

Ask only what would materially change the plan:
- "เป้าหมายสุดท้ายที่ต้องการคืออะไรครับ?"
- "มี deadline หรือ constraint ไหมครับ?"
- "Output ที่ต้องการเป็น format อะไรครับ?"

Do NOT ask what you can research yourself.

### Step 2: Write the Plan

```
**Plan: [Task Name]**

- Goal: [one sentence]
- Steps:
  1. [Agent]: [task] → [expected output]
  2. [Agent]: [task] → [expected output]
  3. Spike: synthesize → deliver to Boom
- Board: [issue title + labels]
- Risks: [known blockers]
- Deliverable: [exactly what Boom will receive]
```

Share plan with Boom. **STOP.** Wait for "approved", "โอเค", "go ahead", "ได้เลย".

### Step 3: Open Board Task (after approval)

Open the GitHub issue (see Section 3 for commands), then proceed to Section 4.

---

## Section 3: Board Task Execution (🟡 MODERATE + 🔴 COMPLEX — ALL agents)

The GitHub Projects board is the **source of truth** for all non-trivial work.

**Board:** https://github.com/orgs/Mone-Industries/projects/7/views/1
**Repo:** `moneai-spdx/sam-team`
**GH Proxy:** `http://gh-proxy-{YOUR_AGENT_ID}:8080`

### Pipeline

```
BACKLOG → READY → IN PROGRESS → IN REVIEW → DONE
```

---

### 3A — Open a Task

```bash
GH=http://gh-proxy-{YOUR_AGENT_ID}:8080

curl -s -X POST "$GH/repos/moneai-spdx/sam-team/issues" \
  -H "Content-Type: application/json" \
  -d '{
    "title": "[SAM] Task description",
    "body": "## Goal\n\n[what needs to be done]\n\n## Acceptance Criteria\n- [ ] criterion 1\n- [ ] criterion 2\n\n## Assignee\n[Tom / Jerry / Spike]",
    "labels": ["ready"]
  }'
# Save the returned issue number
```

**Title format:** `[SAM] Short description` (Spike assigns SAM-NNN numbering on the board)

**Labels to pick from:**
`research` · `km` · `content` · `seo` · `backlink` · `syndication` · `marketing` · `urgent`

---

### 3B — Start Working (move to In Progress)

Comment on the issue when starting:
```bash
GH=http://gh-proxy-{YOUR_AGENT_ID}:8080
ISSUE=123

curl -s -X POST "$GH/repos/moneai-spdx/sam-team/issues/$ISSUE/comments" \
  -H "Content-Type: application/json" \
  -d '{"body": "🔄 In Progress — starting now."}'
```

---

### 3C — Report Progress (for multi-step tasks)

Add a comment when you hit a significant milestone (not after every micro-step):
```bash
curl -s -X POST "$GH/repos/moneai-spdx/sam-team/issues/$ISSUE/comments" \
  -H "Content-Type: application/json" \
  -d '{"body": "📝 Progress — [what was done, what is next]"}'
```

---

### 3D — Complete and Close

When done, comment the result and close:
```bash
# Comment result
curl -s -X POST "$GH/repos/moneai-spdx/sam-team/issues/$ISSUE/comments" \
  -H "Content-Type: application/json" \
  -d '{"body": "✅ Done\n\n[result summary]\n\nKM: [/root/.km/path if applicable]"}'

# Close the issue
curl -s -X PATCH "$GH/repos/moneai-spdx/sam-team/issues/$ISSUE" \
  -H "Content-Type: application/json" \
  -d '{"state": "closed"}'
```

---

### 3E — Blocked? Escalate immediately.

```bash
curl -s -X POST "$GH/repos/moneai-spdx/sam-team/issues/$ISSUE/comments" \
  -H "Content-Type: application/json" \
  -d '{"body": "🚫 Blocked — [what failed]\n\nAttempted: [what was tried]\nNeeds: [what is missing]\n@spike please advise"}'
```

Do NOT silently retry more than 2 times. Escalate to Spike via DM if urgent.

---

## Section 4: Delegation Protocol (🔴 COMPLEX — GM only)

### Assign tasks from the board to workers

After opening issues and adding to board:
1. **Parallel tasks** → assign Tom and Jerry simultaneously via DM
2. **Sequential tasks** → assign one at a time, wait for done comment before next step
3. Brief the worker on: task goal, board issue number, platform service routing

**DM format to workers:**
```
Issue #[NNN] — [task description]
Goal: [one sentence]
Deliver: [expected output]
Use: [Crawl4AI / Brave Search / gh-proxy / etc.]
When done: comment result on the issue + move to IN REVIEW
```

### Checkpoint behavior

After each worker completes:
1. Read their result comment on the issue
2. Verify output is complete and usable
3. If wrong or incomplete → retry once, then handle directly
4. Synthesize results → respond to Boom

---

## Section 5: Verification Before Done (ALL agents — mandatory)

**Never say "เสร็จแล้ว" or close a board task without this checklist.**

### By task type:

| Task type | Must verify |
|-----------|-------------|
| Research | Written to KM vault (`/root/.km/`) |
| Web scraping | Actual content retrieved (not just URL) |
| GitHub | Issue/PR/file visibly exists |
| Writing / content | Matches requested format and length |
| Delegation (GM) | Worker result reviewed before synthesizing |

### General checklist:
- [ ] Deliverable matches exactly what was asked
- [ ] No platform service bypassed when it should have been used
- [ ] Research findings written to KM
- [ ] Board issue commented + closed (if MODERATE or COMPLEX)
- [ ] Blockers reported, not silently skipped

### Response format — match complexity:

**🟢 SIMPLE** — just give the answer. No format needed.
> Result directly, or "เสร็จแล้วครับ — [result]"

**🟡 MODERATE** — one sentence + result + board ref.
> "เสร็จแล้วครับ — [brief result]. ปิด issue #[N] แล้ว"

**🔴 COMPLEX** — structured summary:
```
**Done — [one-line summary]**

- [What was delivered]
- [Where to find it — URL / file path / KM note]
- [Board: issue #N closed]
- [Caveats or follow-up if any]
```

### If verification fails:
```
**Blocked — [what failed]**

- Attempted: [what was tried]
- Missing: [what is needed]
- Board: issue #[N] updated with blocker comment
- Next step: [recommendation]
```

---

## Section 6: Systematic Problem-Solving (when something goes wrong)

### Phase 1: Reproduce
Can you reliably trigger the failure? If NO → report to Spike with details.

### Phase 2: Root Cause
- Platform service down? → run health check (see `SKILL.md`)
- Wrong input format? → re-read original request
- Empty crawl result? → page needs JS → escalate to Browser-use
- Missing data? → search KM first, then web, then ask

### Phase 3: Fix
Make the minimal change needed. Do not redesign the whole approach.

### Phase 4: Verify
Confirm fix works. Follow Section 5 completion format.

**Anti-patterns:**
- Do NOT retry the same failing action more than 2 times
- Do NOT guess-patch without knowing root cause
- Do NOT mark done without verifying the fix worked

---

## Quick Reference

```
Task arrives
    ↓
[Section 1: Triage]
    │
    ├── 🟢 SIMPLE  ─────────────────────────────── act immediately → respond
    │
    ├── 🟡 MODERATE ──── open issue [Section 3A] → work → close [Section 3D]
    │                         ↑
    │                    Section 5: verify first
    │
    └── 🔴 COMPLEX ──── clarify → plan [Section 2]
                             ↓
                        open issue [Section 3A]
                             ↓
                        delegate [Section 4]
                             ↓
                        workers execute [Section 3B→3D]
                             ↓
                        Section 5: verify → respond to Boom

Something goes wrong?
    → Section 6: Systematic Problem-Solving

Board:
    https://github.com/orgs/Mone-Industries/projects/7/views/1
```
