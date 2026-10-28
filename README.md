## Previous competitions
https://github.com/404-Repo/404-competition-0
https://github.com/404-Repo/404-competition-1
https://github.com/404-Repo/404-competition-2

# Competition State Repository

This repository contains the complete state of the 404-GEN competition 3 (`gpt`). Each file is single-writer or append-only so the repo doubles as an audit log.

In `gpt`, miners submit Python source that uses closed-source models to produce a **Three.js module** (one `.js` per prompt). The witness Pod saves the output and renders, and the validator stack judges duels via VLMs. See the [miner guide](https://github.com/404-Repo/404-gen-subnet/tree/feat/witness-public-release/miner-reference) for the root `main.py` contract, supported models and budgets.

## Stages

The competition progresses through well-defined stages. Stage values are lowercase strings on disk.

| Stage | Description | Owner |
|-------|-------------|-------|
| `open` | Submission window open; submission-collector reads on-chain reveals into `submissions.json` | submission-collector |
| `miner_generation` | Seed published; miners run their Python generators and save results through the witness Pod | submission-collector (waits) |
| `collecting` | Collect saved result indexes and record their public URLs and status | submission-collector |
| `duels` | VLM-based pairwise duels, candidate validation, winner selection | judge-service + validator |
| `finalizing` | Update leader history, write next round's schedule | round-manager |
| `finished` | Competition complete, no further rounds | — |
| `paused` | Manual hold for inspection or intervention | — |

```
FINALIZING ──► OPEN ──► MINER_GENERATION ──► COLLECTING  ──► DUELS ──► FINALIZING
     │                                                                      │
     ▼                                                                      │
  FINISHED ◄────────────────────────────────────────────────────────────────┘
```

## Global State

### `config.json`

Competition configuration. Defined by `subnet_common.competition.config.CompetitionConfig`. Manually authored before the competition starts.

```json
{
  "name": "gpt",
  "description": "Image-to-Three.js Generation with Closed-Source Models",
  "first_evaluation_date": "2026-10-26",
  "last_competition_date": "2027-10-26",
  "round_start_time": "08:00:00",
  "generation_stage_minutes": 1440,
  "finalization_buffer_hours": 1,
  "win_margin": 0.07,
  "prompts_per_round": 128,
  "carryover_prompts": 32,
  "round_duration_days": 3
}
```

| Field | Type | Description |
|-------|------|-------------|
| `name` | string | Competition name |
| `description` | string | Competition description |
| `first_evaluation_date` | date | First day of evaluation rounds |
| `last_competition_date` | date | Last allowed day for round start |
| `round_start_time` | time | Daily round start time (UTC) |
| `generation_stage_minutes` | int | Minutes miners have to generate and upload after seed reveal |
| `finalization_buffer_hours` | float | Skip day if FINALIZING with less than this remaining |
| `win_margin` | float | Challenger must win by this fraction of duels to dethrone the leader |
| `prompts_per_round` | int | Number of prompts to select for each round |
| `carryover_prompts` | int | Number of prompts retained from the previous round |
| `round_duration_days` | int | Round duration in days |

**Writer:** Manual.

### `state.json`

Current competition progress. Defined by `CompetitionState`.

```json
{
  "current_round": 0,
  "stage": "open",
  "next_stage_eta": "2026-10-28T08:00:00Z"
}
```

| Field | Type | Description |
|-------|------|-------------|
| `current_round` | int | Active round number |
| `stage` | string | One of `open`, `miner_generation`, `collecting`, `duels`, `finalizing`, `finished`, `paused` |
| `next_stage_eta` | string \| null | Estimated UTC time when the next stage begins (approximate) |

**Writers:** the owner of the current stage updates this file when transitioning out.

### `leader.json`

Leadership history, append-only. **Flat array** of `LeaderEntry` objects (no top-level wrapper).

```json
[
  {
    "hotkey": "5ABC123...",
    "repo": "user/3d-gen-model",
    "commit": "a1b2c3d4e5f6...",
    "docker": "",
    "weight": 1.0,
    "effective_block": 12000
  }
]
```

| Field | Type | Description |
|-------|------|-------------|
| `hotkey` | string | Miner hotkey |
| `repo` | string | GitHub repository |
| `commit` | string | Git commit SHA |
| `docker` | string | Compatibility field; unused for Python generation |
| `weight` | float | Weight assigned to this leader |
| `effective_block` | int | Block number from which this entry is the active leader |

**Writer:** round-manager during FINALIZING.

To find the active leader at block N, take the most recent entry where `effective_block <= N`.

### `prompts.txt`

Global pool of image prompt URLs, one per line. The submission-collector samples from this pool when it freezes a round's prompts.

```
https://cdn.example.com/prompts/<sha>.png
```

**Writer:** Manual.

## Per-Round State

Each round has its own directory: `rounds/{round_number}/`.

### `rounds/{round}/schedule.json`

Round timing in chain blocks. Defined by `RoundSchedule`.

```json
{
  "earliest_reveal_block": 9359301,
  "latest_reveal_block": 9380899,
  "generation_deadline_block": 9388099
}
```

| Field | Type | Description |
|-------|------|-------------|
| `earliest_reveal_block` | int | First block accepting submissions |
| `latest_reveal_block` | int | Last block accepting submissions; seed is revealed after this |
| `generation_deadline_block` | int | Block by which miners must finish uploading their generations |

**Writer:** round-manager during FINALIZING (for the next round).

### `rounds/{round}/submissions.json`

Collected miner submissions for the round, keyed by hotkey. Each value is a `MinerSubmission`.

```json
{
  "5ABC123...": {
    "repo": "user/3d-gen-model",
    "commit": "a1b2c3d4e5f6...",
    "revealed_at_block": 9380000,
    "tie_breaker": "00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000",
    "round": "gpt-0"
  }
}
```

| Field | Type | Description |
|-------|------|-------------|
| `repo` | string | GitHub repository in `owner/repo` form |
| `commit` | string | Git commit SHA |
| `revealed_at_block` | int | Block number when the submission was revealed |
| `tie_breaker` | string | Seed-based BLAKE2b digest for ordering reveals in the same block |
| `round` | string | Full round identifier (`<competition_name>-<round_number>`) |

**Writer:** submission-collector during OPEN.

### `rounds/{round}/seed.json`

Random seed for deterministic prompt selection and generation.

```json
{ "seed": 847291 }
```

**Writer:** submission-collector at the end of OPEN.

### `rounds/{round}/prompts.txt`

URLs of image prompts selected for this round, one per line.

**Writer:** submission-collector at the end of OPEN.

### `rounds/{round}/validation_requests.json`

Flat array of hotkeys that need Python replay validation. Written when a miner becomes a candidate winner during the DUELS stage.

```json
[ { "hotkey": "5ABC123..." } ]
```

| Field | Type | Description |
|-------|------|-------------|
| `hotkey` | string | Miner hotkey to regenerate |

**Writer:** judge-service during DUELS. Deduplicated by hotkey.

### `rounds/{round}/validation_results.json`

Terminal replay-validation verdicts, keyed by hotkey. A missing entry means validation is pending.

```json
{
  "5ABC123...": {
    "verdict": "passed",
    "reason": ""
  }
}
```

| Field | Type | Description |
|-------|------|-------------|
| `verdict` | string | One of `passed`, `failed` |
| `reason` | string | Required explanation if `failed` |

**Writer:** validator during DUELS.

### `rounds/{round}/source_audit.json`

Manual / external source-code audit results — license compliance, reproducibility, malware/security, banned patterns. Flat array of `AuditResult`.

```json
[
  { "hotkey": "5ABC123...", "verdict": "passed", "reason": "" }
]
```

| Field | Type | Description |
|-------|------|-------------|
| `hotkey` | string | Miner hotkey |
| `verdict` | string | One of `passed`, `failed` |
| `reason` | string | Explanation if `failed` |

**Writer:** Manual / external audit service.

### `rounds/{round}/matches_matrix.csv`

All pairwise duel margins for the round, in CSV.

```csv
left,right,margin
leader,5ABC123...,0.15
leader,5DEF456...,-0.10
5ABC123...,5DEF456...,0.05
```

| Column | Description |
|--------|-------------|
| `left` | Defender hotkey (the literal string `leader` for the incumbent) |
| `right` | Challenger hotkey |
| `margin` | `score / total_duels`; positive = challenger wins, negative = defender wins. Promotion requires `margin >= config.win_margin` |

**Writer:** judge-service during DUELS.

### `rounds/{round}/winner.json`

Round result. `RoundResult`.

```json
{
  "winner_hotkey": "5ABC123...",
  "repo": "user/3d-gen-model",
  "commit": "a1b2c3d4e5f6..."
}
```

| Field | Type | Description |
|-------|------|-------------|
| `winner_hotkey` | string | Hotkey of the winning miner, or the literal `leader` if the incumbent defended |
| `repo` | string | Winner's GitHub repository |
| `commit` | string | Winner's commit SHA |

**Writer:** judge-service at the end of DUELS.

## Per-Miner State

Each miner has its own directory: `rounds/{round_number}/{hotkey}/`. The leader's baseline outputs use the literal directory name `leader/` (see "Pseudo-hotkey" below).

### `rounds/{round}/{hotkey}/submitted.json`

Outputs collected from the witness Pod's saved result index. Map of prompt stem → `GenerationResult`.

```json
{
  "<prompt-stem>": {
    "js": "https://subnet404.xyz/rounds/gpt-0/5ABC123/submitted/<stem>.js",
    "views": "https://subnet404.xyz/rounds/gpt-0/5ABC123/submitted/<stem>",
    "failure_reason": null,
    "size": 7806
  }
}
```

| Field | Type | Description |
|-------|------|-------------|
| `js` | string \| null | CDN URL to the Three.js module. `null` if the miner did not submit anything for this stem |
| `views` | string \| null | CDN folder prefix containing the rendered view bundle. The judge constructs URLs by convention: `{views}/white/{view}.png`, `{views}/gray/{view}.png`, plus `{views}/grid.png` and `{views}/embeddings.npz`. `null` if any render or embedding step failed (atomic — all 12 views succeed or none are uploaded) |
| `failure_reason` | string \| null | Failure status (e.g. `not_submitted`, `generation_failed`, `render_rejected`). `null` on a clean delivery |
| `size` | int | Size of the JS module in bytes (0 when missing) |

**Writer:** submission-collector during COLLECTING.

### `rounds/{round}/leader/generated.json`

Same schema as `submitted.json`, containing the leader's baseline results for the round's prompts and seed.

**Writer:** leader generation / submission-collector.

### `rounds/{round}/{hotkey}/duels_{opponent[:10]}.json`

Detailed per-prompt match report for one matchup. Stored in the **challenger's** directory; the file is named after the first 10 characters of the **defender's** hotkey.

```json
{
  "left": "leader",
  "right": "5ABC123...",
  "score": 4,
  "margin": 0.10,
  "duels": [
    {
      "name": "<prompt-stem>",
      "prompt": "https://cdn.example.com/prompts/<stem>.png",
      "left_js": "https://subnet404.xyz/rounds/gpt-0/leader/generated/<stem>.js",
      "left_png": "https://subnet404.xyz/rounds/gpt-0/leader/generated/<stem>/white/front.png",
      "right_js": "https://subnet404.xyz/rounds/gpt-0/5ABC123/submitted/<stem>.js",
      "right_png": "https://subnet404.xyz/rounds/gpt-0/5ABC123/submitted/<stem>/white/front.png",
      "winner": "right",
      "detail": { "stages": [ /* per-stage VLM scores + DINOv3 similarities */ ] }
    }
  ]
}
```

| Field | Type | Description |
|-------|------|-------------|
| `left` | string | Defender hotkey (`leader` for the incumbent) |
| `right` | string | Challenger hotkey |
| `score` | int | Net score: +1 per win, −1 per loss, 0 per draw |
| `margin` | float | `score / len(duels)` — used by judge-service to populate `matches_matrix.csv` |
| `duels` | array | Per-prompt duel results |
| `duels[].name` | string | Prompt stem |
| `duels[].prompt` | string | URL to the prompt image |
| `duels[].left_js` / `right_js` | string \| null | URL to each side's Three.js module |
| `duels[].left_png` / `right_png` | string \| null | URL to a representative rendered preview |
| `duels[].winner` | string | One of `left`, `right`, `draw`, `skipped` |
| `duels[].detail` | object \| null | Free-form per-stage trace from the multi-stage judge: numeric scores, DINOv3 similarities, etc. (VLM `issues` text is dropped to bound size) |

**Writer:** judge-service during DUELS.

## Pseudo-hotkey `leader`

When the incumbent leader successfully defends a round, the literal string `leader` is used in three places instead of the actual hotkey:

- `winner.json` → `winner_hotkey: "leader"`
- `matches_matrix.csv` → `left` column for matches where the incumbent is the defender
- The leader's baseline outputs live at `rounds/{round}/leader/generated.json`

`leader.json` always stores the **real** hotkey of each transition — it's the source of truth for resolving who `leader` refers to at a given block.

## File Write Order

```
FINALIZING (round N-1)
  └── rounds/{N}/schedule.json
  └── leader.json (append)
  └── state.json → open

OPEN
  └── rounds/{N}/submissions.json
  └── rounds/{N}/seed.json
  └── rounds/{N}/prompts.txt
  └── state.json → miner_generation

MINER_GENERATION
  └── (miners save results through the witness Pod)
  └── state.json → collecting

COLLECTING
  └── rounds/{N}/{hotkey}/submitted.json  (one per miner)
  └── state.json → duels

DUELS
  └── rounds/{N}/{hotkey}/duels_*.json
  └── rounds/{N}/matches_matrix.csv
  └── rounds/{N}/validation_requests.json
  └── rounds/{N}/validation_results.json
  └── rounds/{N}/winner.json
  └── state.json → finalizing
```

## External Storage

Three.js modules, rendered PNG views, grid composites, and DINOv3 embeddings are stored on the validators' R2/CDN (the `subnet404.xyz` host in examples). On-disk JSON files only reference these via URL.

## Verification Pipeline

When a miner becomes a candidate winner:

1. judge-service appends the miner's hotkey to `validation_requests.json`
2. The validator replays the submitted Python source with recorded model traffic and checks the result and budgets
3. The validator writes a terminal `passed` or `failed` verdict to `validation_results.json`
4. judge-service uses that verdict when selecting the winner
