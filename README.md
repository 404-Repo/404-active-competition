## Previous competitions
https://github.com/404-Repo/404-competition-0
https://github.com/404-Repo/404-competition-1

# Competition State Repository

This repository contains the complete state of the 404-GEN `threejs` competition. Each file is single-writer or append-only so the repo doubles as an audit log.

In `threejs`, miners produce a **Three.js module** (one `.js` per prompt) for each input image prompt. The validator stack downloads the `.js`, renders multi-view PNGs, runs DINOv3 on the prompt + views, and judges duels via VLMs.

## Stages

The competition progresses through well-defined stages. Stage values are lowercase strings on disk.

| Stage | Description | Owner |
|-------|-------------|-------|
| `open` | Submission window open; submission-collector reads on-chain reveals into `submissions.json` | submission-collector |
| `miner_generation` | Seed published; miners run their generators and upload `.js` files to their CDNs | submission-collector (waits) |
| `downloading` | Validators fetch `.js`, render 12 white + 4 gray views, compute embeddings, upload to R2 | submission-collector |
| `duels` | VLM-based pairwise duels, candidate-winner regeneration, verification audits, winner selection | judge-service + generation-orchestrator |
| `finalizing` | Update leader history, write next round's schedule | round-manager |
| `finished` | Competition complete, no further rounds | — |
| `paused` | Manual hold for inspection or intervention | — |

```
FINALIZING ──► OPEN ──► MINER_GENERATION ──► DOWNLOADING ──► DUELS ──► FINALIZING
     │                                                                      │
     ▼                                                                      │
  FINISHED ◄────────────────────────────────────────────────────────────────┘
```

## Global State

### `config.json`

Competition configuration. Defined by `subnet_common.competition.config.CompetitionConfig`. Manually authored before the competition starts.

```json
{
  "name": "threejs",
  "description": "Image-to-Three.js Generation",
  "first_evaluation_date": "2026-04-29",
  "last_competition_date": "2027-02-02",
  "round_start_time": "08:00:00",
  "generation_stage_minutes": 240,
  "finalization_buffer_hours": 1,
  "win_margin": 0.05,
  "weight_decay": 0.2,
  "weight_floor": 0.2,
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
| `weight_decay` | float | Weight reduction per round if leader is not defeated |
| `weight_floor` | float | Minimum leader weight |
| `prompts_per_round` | int | Number of prompts to select for each round |
| `carryover_prompts` | int | Number of prompts retained from the previous round |
| `round_duration_days` | int | Round duration in days |

**Writer:** Manual.

### `state.json`

Current competition progress. Defined by `CompetitionState`.

```json
{
  "current_round": 1,
  "stage": "open",
  "next_stage_eta": "2026-04-29T08:00:00Z"
}
```

| Field | Type | Description |
|-------|------|-------------|
| `current_round` | int | Active round number |
| `stage` | string | One of `open`, `miner_generation`, `downloading`, `duels`, `finalizing`, `finished`, `paused` |
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
    "docker": "europe-west3-docker.pkg.dev/.../dendrite-test:0.0.1",
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
| `docker` | string | Docker image reference |
| `weight` | float | Weight assigned to this leader (new winners enter at 1.0; defending leaders decay toward `weight_floor`) |
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
  "earliest_reveal_block": 12400,
  "latest_reveal_block": 12450,
  "generation_deadline_block": 12550
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
    "cdn_url": "https://cdn.miner.com/round-1",
    "revealed_at_block": 12425,
    "round": "threejs-1"
  }
}
```

| Field | Type | Description |
|-------|------|-------------|
| `repo` | string | GitHub repository in `owner/repo` form |
| `commit` | string | Git commit SHA |
| `cdn_url` | string | CDN URL prefix where the miner uploaded its `<stem>.js` files |
| `revealed_at_block` | int | Block number when the submission was revealed |
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

### `rounds/{round}/builds.json`

Container build status per miner. Keyed by hotkey, value is `BuildInfo`.

```json
{
  "5ABC123...": {
    "repo": "user/3d-gen-model",
    "commit": "a1b2c3d4e5f6...",
    "revealed_at_block": 12425,
    "tag": "a1b2c3d-threejs-1",
    "status": "success",
    "docker_image": "ghcr.io/user/3d-gen-model:a1b2c3d-threejs-1"
  }
}
```

| Field | Type | Description |
|-------|------|-------------|
| `repo` | string | GitHub repository |
| `commit` | string | Git commit SHA |
| `revealed_at_block` | int | Block number of the original reveal |
| `tag` | string | Docker image tag (`{commit[:7]}-{round}`) |
| `status` | string | One of `pending`, `in_progress`, `success`, `failure`, `timed_out`, `not_found` |
| `docker_image` | string \| null | Docker image URL if the build succeeded |

**Writer:** generation-orchestrator during DUELS.

### `rounds/{round}/require_audit.json`

Flat array of hotkeys that need verification regeneration. Written when a miner becomes a candidate winner during the DUELS stage.

```json
[ { "hotkey": "5ABC123..." } ]
```

| Field | Type | Description |
|-------|------|-------------|
| `hotkey` | string | Miner hotkey to regenerate |

**Writer:** judge-service during DUELS. Deduplicated by hotkey.

### `rounds/{round}/generation_reports.json`

Status reports from the generation-orchestrator's regeneration runs, keyed by hotkey.

```json
{
  "5ABC123...": {
    "hotkey": "5ABC123...",
    "outcome": "completed",
    "checked_prompts": 128,
    "failed_prompts": 1,
    "generation_time": 45.2,
    "reason": ""
  }
}
```

| Field | Type | Description |
|-------|------|-------------|
| `hotkey` | string | Miner hotkey |
| `outcome` | string | One of `pending`, `completed`, `rejected` |
| `checked_prompts` | int | Number of prompts regenerated so far |
| `failed_prompts` | int | Prompts that failed to regenerate |
| `generation_time` | float \| null | Trimmed median per-prompt generation time, in seconds |
| `reason` | string | Rejection reason if applicable |

**Writer:** generation-orchestrator during DUELS.

### `rounds/{round}/verification_audits.json`

Verification verdicts produced by the judge after a re-run. The judge re-duels each miner's `submitted` outputs vs the `generated` ones; per-prompt outcomes contribute +1 (submitted wins), −1 (generated wins), or 0 (draw / skip). The hotkey passes if `score >= 0`.

```json
{
  "5ABC123...": {
    "hotkey": "5ABC123...",
    "outcome": "passed",
    "score": 6,
    "checked_prompts": 12,
    "reason": ""
  }
}
```

| Field | Type | Description |
|-------|------|-------------|
| `hotkey` | string | Miner hotkey |
| `outcome` | string | One of `pending`, `passed`, `failed` |
| `score` | int | Sum of per-prompt outcomes (+1 submitted / −1 generated / 0 otherwise) |
| `checked_prompts` | int | Number of prompts that contributed a non-zero score |
| `reason` | string | Explanation if `failed` |

**Writer:** judge-service during DUELS.

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
  "commit": "a1b2c3d4e5f6...",
  "docker_image": "ghcr.io/user/3d-gen-model:a1b2c3d-threejs-1"
}
```

| Field | Type | Description |
|-------|------|-------------|
| `winner_hotkey` | string | Hotkey of the winning miner, or the literal `leader` if the incumbent defended |
| `repo` | string | Winner's GitHub repository |
| `commit` | string | Winner's commit SHA |
| `docker_image` | string | Docker image of the winner |

**Writer:** judge-service at the end of DUELS.

## Per-Miner State

Each miner has its own directory: `rounds/{round_number}/{hotkey}/`. The leader's regenerated outputs use the literal directory name `leader/` (see "Pseudo-hotkey" below).

### `rounds/{round}/{hotkey}/submitted.json`

Outputs the validator collected from the miner's CDN. Map of prompt stem → `GenerationResult`.

```json
{
  "<prompt-stem>": {
    "js": "https://subnet404.xyz/rounds/1/5ABC123/submitted/<stem>.js",
    "views": "https://subnet404.xyz/rounds/1/5ABC123/submitted/<stem>",
    "failure_reason": null,
    "size": 7806
  }
}
```

| Field | Type | Description |
|-------|------|-------------|
| `js` | string \| null | CDN URL to the Three.js module. `null` if the miner did not submit anything for this stem |
| `views` | string \| null | CDN folder prefix containing the rendered view bundle. The judge constructs URLs by convention: `{views}/white/{view}.png`, `{views}/gray/{view}.png`, plus `{views}/grid.png` and `{views}/embeddings.npz`. `null` if any render or embedding step failed (atomic — all 12 views succeed or none are uploaded) |
| `failure_reason` | string \| null | Categorical failure string from the collector pipeline (e.g. `js_fetch_failed: HTTP 404`, `render_failed`, `embeddings_failed`). `null` on a clean delivery |
| `size` | int | Size of the JS module in bytes (0 when missing) |

**Writer:** submission-collector during DOWNLOADING. Saved after each prompt for crash recovery.

### `rounds/{round}/{hotkey}/generated.json`

Same schema as `submitted.json`, populated by re-running the miner's container on the round's seed. On the GENERATED source, `failure_reason` originates from the miner's own `_failed.json` manifest rather than from the collector.

**Writer:** generation-orchestrator during DUELS.

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
      "left_js": "https://subnet404.xyz/rounds/1/leader/generated/<stem>.js",
      "left_png": "https://subnet404.xyz/rounds/1/leader/generated/<stem>/white/front.png",
      "right_js": "https://subnet404.xyz/rounds/1/5ABC123/submitted/<stem>.js",
      "right_png": "https://subnet404.xyz/rounds/1/5ABC123/submitted/<stem>/white/front.png",
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

### `rounds/{round}/{hotkey}/pod_stats.json`

Generation-orchestrator diagnostics from the GPU pod that ran this miner's regeneration. Map of `pod_id` → `PodStats` (a single hotkey may span multiple pods if one is replaced).

```json
{
  "miner-01-a1b2c3d4-0": {
    "pod_id": "miner-01-a1b2c3d4-0",
    "provider": "runpod",
    "batch_times": [266.3, 245.1, 234.7],
    "total_generation_time": 991.4,
    "termination_reason": "completed",
    "payload": null
  }
}
```

| Field | Type | Description |
|-------|------|-------------|
| `pod_id` | string | Worker identifier |
| `provider` | string | GPU provider (`targon`, `runpod`, …) |
| `batch_times` | float[] | Wall-clock seconds per batch |
| `total_generation_time` | float | Total wall-clock generation time in seconds |
| `termination_reason` | string | e.g. `completed`, `crashed`, `replace_requested` |
| `payload` | object \| null | Diagnostic payload from the miner at termination (e.g. health report) |

**Writer:** generation-orchestrator during DUELS.

## Pseudo-hotkey `leader`

When the incumbent leader successfully defends a round, the literal string `leader` is used in three places instead of the actual hotkey:

- `winner.json` → `winner_hotkey: "leader"`
- `matches_matrix.csv` → `left` column for matches where the incumbent is the defender
- The leader's regenerated outputs live at `rounds/{round}/leader/generated.json` and `rounds/{round}/leader/pod_stats.json` (judge-service routes the leader through `GenerationSource.GENERATED` because there is no submitted file for it)

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
  └── (miners upload to their CDNs)
  └── state.json → downloading

DOWNLOADING
  └── rounds/{N}/{hotkey}/submitted.json  (one per miner)
  └── state.json → duels

DUELS
  └── rounds/{N}/builds.json
  └── rounds/{N}/{hotkey}/duels_*.json
  └── rounds/{N}/matches_matrix.csv
  └── rounds/{N}/require_audit.json
  └── rounds/{N}/{hotkey}/generated.json   (candidate winners + leader)
  └── rounds/{N}/{hotkey}/pod_stats.json
  └── rounds/{N}/generation_reports.json
  └── rounds/{N}/verification_audits.json
  └── rounds/{N}/winner.json
  └── state.json → finalizing
```

## External Storage

Three.js modules, rendered PNG views, grid composites, and DINOv3 embeddings are stored on the validators' R2/CDN (the `subnet404.xyz` host in examples). On-disk JSON files only reference these via URL.

## Verification Pipeline

When a miner becomes a candidate winner:

1. judge-service appends the miner's hotkey to `require_audit.json`
2. generation-orchestrator deploys the miner's Docker image to a GPU pod (`pod_stats.json`)
3. Orchestrator regenerates every round prompt with `seed.json`'s seed and writes results to `{hotkey}/generated.json`; status lands in `generation_reports.json`
4. judge-service runs a verification duel between `submitted.json` and `generated.json`; per-prompt outcomes (+1 / −1 / 0) are summed into `verification_audits.json`
5. Pass condition is `score >= 0`. On `failed`, the timeline is discarded and alternative winners are considered

The same pipeline runs for the incumbent `leader` (always via the GENERATED source, since the leader has no submission for the round).
