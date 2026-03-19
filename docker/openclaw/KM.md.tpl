---
name: ${TEAM_NAME}-km
description: Knowledge Management — Obsidian vault SOP for ${TEAM_NAME} agents. Full rules for creating and finding knowledge.
---

# Knowledge Management — Obsidian Vault SOP

> KM is the long-term brain of the entire agent team.
> Every agent MUST know how to use it — both writing and reading.
> Think of it as a library: structured index, consistent format, bidirectional links.

---

## Mental Model — How This Vault Works

```
User asks question
        │
        ▼
[1] Semantic search → finds most relevant note (entry point)
        │
        ▼
[2] Read that note → follow [[wikilinks]] to related notes (multi-hop)
        │
        ▼
[3] If no note found → do research → write note → update MOC
        │
        ▼
[4] Answer user with cited KM sources
```

The vault has **two layers**:
- **MOC layer** — index notes (the library catalog). Know what exists and where.
- **Content layer** — actual knowledge notes. Atomic, linked, tagged.

---

## Vault Structure

```
/root/.km/
├── MOC/
│   ├── 00-MOC-Home.md           ← MASTER INDEX — read this first when lost
│   ├── 01-MOC-Projects.md       ← all project-related knowledge
│   ├── 02-MOC-Research.md       ← web research findings & summaries
│   ├── 03-MOC-Tech.md           ← tech stack, APIs, libraries, patterns
│   └── 04-MOC-Processes.md      ← workflows, SOPs, agent procedures
├── Projects/                    ← one subfolder per project
├── Research/                    ← web research summaries (with source URLs)
├── Tech/                        ← technical notes, patterns, solutions
├── Daily/                       ← session logs, date-prefixed
└── Assets/                      ← attachments (rarely used by agents)
```

**Principle:** Folders = broad categories only. Links + MOC = actual organization.

---

## Obsidian Concepts Agents Must Understand

### 1. Wikilinks `[[Note Title]]`
- Creates a **bidirectional link** between two notes
- Obsidian renders this as a clickable edge in the knowledge graph
- Agent rule: every note MUST link to at least 1 MOC + 1 related note
- To find all notes linking TO a note: `grep -r "[[Note Title]]" /root/.km/ --include="*.md" -l`

### 2. MOC (Map of Content)
- An index note that **links to** a group of related notes
- NOT a folder — it's a navigational hub inside the vault
- Reading the relevant MOC = fastest way to find existing knowledge
- Rule: when you write 3+ notes on the same subtopic → create a sub-MOC

### 3. Evergreen Notes
- Atomic, permanent, reusable facts (tag: `#evergreen`)
- One idea per note — not a dump of everything
- Written to be useful forever, not just for today's task
- Example: `react-server-components-pattern.md` (not `react-research-march-2026.md`)

### 4. Frontmatter (YAML metadata)
- Machine-readable metadata at the top of every note
- Enables fast filtering without reading full content
- Required fields: `title`, `tags`, `created`, `agent`
- Optional: `source`, `project`, `status`

### 5. Tags
- `#tag` in frontmatter for broad grouping
- Use for filtering, not for organizing hierarchy (that's what MOC/links are for)

### 6. Backlinks
- Any note that contains `[[This Note]]` is a backlink
- Backlinks = how you discover what depends on or references a note
- Find backlinks: `grep -r "\[\[Note Title\]\]" /root/.km/ --include="*.md"`

---

## Standard Note Format

```markdown
---
title: Descriptive Title in Plain English
tags: [tag1, tag2, tag3]
created: YYYY-MM-DD
agent: AGENT_NAME
source: https://url-if-from-web.com
project: project-name (optional)
status: draft | complete | evergreen
---

# Descriptive Title in Plain English

**One-sentence summary of what this note captures.**

## Key Points
- Point 1
- Point 2
- Point 3

## Details

Expand here only if needed. Keep it focused on ONE idea.

## References
- [[MOC/relevant-moc-name]]
- [[Related Note 1]]
- [[Related Note 2]]
```

**Hard rules:**
- One idea per note (split if it covers 2+ distinct ideas)
- `title` in frontmatter must match `# H1` heading
- Always link to at least 1 MOC in `## References`
- `status: evergreen` only when fact is permanent and verified

---

## SOP — Writing to KM (Creator Role)

Follow this exact sequence every time:

### Step 1 — Check for duplicates first
```bash
grep -r "keyword" /root/.km/ --include="*.md" -l
# or use semantic memory search tool
```
If similar note exists → **update it**, don't create duplicate.

### Step 2 — Choose the right folder

| Content type | Folder |
|-------------|--------|
| Web research summary | `Research/` |
| Technical fact, API, pattern | `Tech/` |
| Project-specific finding | `Projects/{project-name}/` |
| Workflow / SOP | `MOC/` or root |
| Daily session log | `Daily/` |

### Step 3 — Write the note (atomic, one idea)
```bash
cat > /root/.km/Research/topic-name.md << 'EOF'
---
title: Topic Name
tags: [research, topic]
created: $(date +%Y-%m-%d)
agent: AGENT_NAME
source: https://source-url.com
status: complete
---

# Topic Name

**One-sentence summary.**

## Key Points
- Finding 1
- Finding 2
- Finding 3

## References
- [[MOC/02-MOC-Research]]
- [[Related Note If Any]]
EOF
```

### Step 4 — Update the relevant MOC
```bash
# Add a line to the appropriate MOC
echo "- [[Research/topic-name]] — one-line description" >> /root/.km/MOC/02-MOC-Research.md
```

### Step 5 — Update 00-MOC-Home if it's a new topic cluster
Only needed when this is the first note in a new subject area.

---

## SOP — Reading from KM (Consumer Role)

### Path A — I know the topic area
```bash
# 1. Read the relevant MOC to see what's available
cat /root/.km/MOC/02-MOC-Research.md

# 2. Open the specific note
cat /root/.km/Research/topic-name.md

# 3. Follow [[wikilinks]] for deeper context
cat /root/.km/Tech/related-note.md
```

### Path B — I don't know where to look
```bash
# 1. Start at the master index
cat /root/.km/MOC/00-MOC-Home.md

# 2. Use semantic search (built-in memory tool) with keywords
# → finds most relevant note as entry point

# 3. From that note, follow [[wikilinks]] (multi-hop)
```

### Path C — Specific keyword search
```bash
grep -r "keyword" /root/.km/ --include="*.md" -l
# → list of files containing keyword
# → read the most relevant ones
```

### Multi-hop Reading Rule
When reading a note:
1. Read the note content
2. Identify `[[linked notes]]` in `## References`
3. If topic requires deeper context → read those linked notes too
4. Stop at ${KM_MAX_HOPS} hops — if still insufficient, do fresh research and write new note

---

## MOC Maintenance Rules

| Event | Action |
|-------|--------|
| Write new note | Add entry to relevant MOC |
| Write 3+ notes on same subtopic | Create sub-MOC, link from parent MOC |
| Note becomes outdated | Update `status: draft`, add `## Update` section |
| Duplicate notes found | Merge into one, update all backlinks |
| New project starts | Create `Projects/{name}/` + add to `01-MOC-Projects.md` |

---

## Tagging Reference

| Tag | When to use |
|-----|-------------|
| `#research` | Web research findings |
| `#tech` | Technical facts, APIs, patterns |
| `#project` | Project-specific knowledge |
| `#process` | Workflows, SOPs |
| `#daily` | Session logs |
| `#evergreen` | Timeless, permanent facts |
| `#draft` | Incomplete, needs more work |

---

## File Naming Rules

- Format: `kebab-case-descriptive-name.md`
- Good: `react-server-components-data-fetching.md`
- Bad: `react-notes.md`, `research1.md`, `temp.md`
- Daily logs: `YYYY-MM-DD-session.md`
- Projects: `Projects/project-name/feature-name.md`

---

## End-of-Task Checklist

Before marking any task complete:

- [ ] Did I learn something new or find useful information? → **Write a note**
- [ ] Did I do web research? → **Summarize in `Research/`**
- [ ] Did I discover a technical pattern or solution? → **Write in `Tech/`**
- [ ] Did I write a new note? → **Update the relevant MOC**
- [ ] Is there a related note I should link to? → **Add `[[wikilink]]`**
- [ ] Should I search KM before doing new research? → **Yes, always**

---

## Embedding Memory Integration

The embedding model (`nomic-embed-text`) indexes every file in `/root/.km/` automatically.

**How it works:**
- Each `.md` file is chunked and embedded as vectors
- Semantic search finds the most relevant file(s) based on query meaning
- The model does NOT follow `[[wikilinks]]` automatically

**Therefore:**
1. Use semantic search as the **entry point** to find the right note
2. Then **manually follow `[[links]]`** to traverse the graph
3. MOC notes act as high-signal hubs — they're rich with topic keywords, making them likely search hits that then guide you to specific notes

**This is why frontmatter and titles matter:** they increase the signal density of each note, making semantic search more accurate.

---

## Token Optimization — Critical Rules

> Reading the full KM graph blindly will destroy your context budget.
> These rules are mandatory. Violating them wastes tokens and degrades performance.

### The Token Budget Ladder

Always use the **cheapest technique first**. Escalate only if insufficient.

| Level | Technique | Token cost | When to use |
|-------|-----------|-----------|-------------|
| 1 | Semantic search (built-in) | ~0 | Always start here |
| 2 | Read frontmatter only | ~50 tok/note | Confirm relevance before full read |
| 3 | Read first section only (`head`) | ~100–200 tok | Skim for relevance |
| 4 | Read full note | ~300–800 tok | Confirmed relevant |
| 5 | Follow 1 wikilink | +300–800 tok | Need deeper context |
| 6 | Follow 2nd wikilink | +300–800 tok | Only if level 5 insufficient |
| **STOP** | Max ${KM_MAX_HOPS} hops | — | Never traverse more than ${KM_MAX_HOPS} linked notes |

### Technique 1 — Frontmatter-first (scan before read)

Read only YAML frontmatter to check relevance before loading the full note:

```bash
# Read first 10 lines (frontmatter only) — ~50 tokens
head -10 /root/.km/Research/topic-name.md
```

If `tags` and `title` match your need → read full note.
If not → skip. Do not load it.

### Technique 2 — MOC as precision filter

MOC entries are one-line summaries with links. Reading a MOC = reading a table of contents (~200 tokens) instead of reading 20 full notes (~10,000 tokens).

```bash
# Read MOC to see what's available — cheap
cat /root/.km/MOC/02-MOC-Research.md

# Then open only the 1-2 notes that match
cat /root/.km/Research/specific-note.md
```

**Never read all notes in a folder. Read MOC first, then cherry-pick.**

### Technique 3 — Targeted grep before reading

```bash
# Find which files mention your keyword — free
grep -r "keyword" /root/.km/ --include="*.md" -l

# Read only the matched files
```

### Technique 4 — Section-only read

If a note is long, read only the relevant section:

```bash
# Read first 30 lines — gets title + key points
head -30 /root/.km/Tech/long-note.md
```

### Multi-hop Hard Limits

```
Semantic search → Note A (full read) → 1 wikilink → Note B (full read) → STOP
                                                                            ↑
                                        If still insufficient: do new research
```

- **Max ${KM_MAX_HOPS} hops** from entry point — hard limit
- **Never follow all links** in a note — pick the single most relevant one
- **Never read a MOC fully linked chain** — MOC → 1 note only, not MOC → all notes
- If ${KM_MAX_HOPS} hops yield nothing useful → stop KM search, do fresh research, write new note

### Stop Conditions

Stop KM traversal immediately when:
- You have enough to answer the question
- You've read entry note + ${KM_MAX_HOPS} hops (total budget exhausted)
- Remaining links are tangentially related
- You've spent >1500 tokens on KM reading for a simple query
