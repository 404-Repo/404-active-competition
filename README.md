## Previous competition
https://github.com/404-Repo/404-competition-0

# Competition State Repository

This repository contains the complete state of the 404-GEN competition. All files are append-only or single-writer, ensuring a clean audit trail.

## Stages

The competition progresses through well-defined stages:

| Stage | Description |
|-------|-------------|
| `open` | Submission window opens, miners register their submissions on-chain |
| `miner_generation` | Seed published, miners generate 3D models and upload to their CDNs |
| `downloading` | Validators fetch 3D files from miner CDNs and render previews |
| `duels` | VLM-based pairwise comparisons, verification requests, winner selection |
| `finalizing` | Updating the leader and creating the next round schedule |
| `finished` | Competition complete, no further rounds |
| `paused` | Manual hold for inspection or intervention |

```
FINALIZING ──► OPEN ──► MINER_GENERATION ──► DOWNLOADING ──► DUELS ──► FINALIZING
     │                                                                      │
     ▼                                                                      │
  FINISHED ◄────────────────────────────────────────────────────────────────┘
```

## Global State

### `config.json`

Competition configuration. Manually created before competition starts.

```json
{
  "name": "404-GEN Competition 1",
  "description": "AI-powered 3D model generation competition",
  "first_evaluation_date": "2025-02-01",
  "last_competition_date": "2025-04-01",
  "round_start_time": "08:00:00",
  "generation_stage_minutes": 180,
  "finalization_buffer_hours": 1.0,
  "win_margin": 0.05,
  "weight_decay": 0.05,
  "weight_floor": 0.1,
  "prompts_per_round": 20,
  "carryover_prompts": 5,
  "round_duration_days": 1
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
| `win_margin` | float | Challenger must win by this fraction to dethrone leader |
| `weight_decay` | float | Weight reduction per round if leader not defeated |
| `weight_floor` | float | Minimum leader weight |
| `prompts_per_round` | int | Number of prompts to select for each round |
| `carryover_prompts` | int | Number of prompts retained from the previous round |
| `round_duration_days` | int | Round duration in days |

**Writer:** Manual (created before competition starts).

### `state.json`

Current competition progress.

```json
{
  "current_round": 1,
  "stage": "open",
  "next_stage_eta": "2025-02-01T11:00:00Z"
}
```

| Field | Type | Description |
|-------|------|-------------|
| `current_round` | int | Active round number |
| `stage` | string | One of: `open`, `miner_generation`, `downloading`, `duels`, `finalizing`, `finished`, `paused` |
| `next_stage_eta` | string \| null | Estimated UTC time when the next stage begins (approximate) |

**Writers:** Each stage owner updates this file when transitioning to the next stage.

### `leader.json`

Leadership history, append-only. Stored as a flat array of transitions.

```json
[
  {
    "hotkey": "5ABC123...",
    "repo": "user/3d-gen-model",
    "commit": "a1b2c3d4e5f6...",
    "docker": "ghcr.io/user/3d-gen-model:a1b2c3d",
    "weight": 1.0,
    "effective_block": 12000
  },
  {
    "hotkey": "5DEF456...",
    "repo": "other/better-model",
    "commit": "f6e5d4c3b2a1...",
    "docker": "ghcr.io/other/better-model:f6e5d4c",
    "weight": 1.0,
    "effective_block": 12500
  }
]
```

| Field | Type | Description |
|-------|------|-------------|
| `hotkey` | string | Miner hotkey |
| `repo` | string | GitHub repository |
| `commit` | string | Git commit SHA |
| `docker` | string | Docker image reference |
| `weight` | float | Weight assigned to this leader |
| `effective_block` | int | Block number when this leader becomes active |

**Writer:** `round-manager` during FINALIZING stage.

To find the active leader at block N, find the most recent entry where `effective_block <= N`.

### `prompts.txt`

Global pool of image prompt URLs, one per line.

```
https://cdn.example.com/prompts/car.png
https://cdn.example.com/prompts/chair.png
https://cdn.example.com/prompts/mug.png
```

**Writer:** Manual (maintained separately).

## Per-Round State

Each round has its own directory: `rounds/{round_number}/`

### `rounds/{round}/schedule.json`

Round timing configuration.

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
| `latest_reveal_block` | int | Last block accepting submissions (seed revealed after this) |
| `generation_deadline_block` | int | Block by which miners must upload their generations |

**Writer:** `round-manager` during FINALIZING stage (for the next round).

### `rounds/{round}/submissions.json`

Collected miner submissions, keyed by hotkey.

```json
{
  "5ABC123...": {
    "repo": "user/3d-gen-model",
    "commit": "a1b2c3d4e5f6...",
    "cdn_url": "https://cdn.miner.com/generations",
    "revealed_at_block": 12425,
    "round": "404-gen-comp1-r1"
  },
  "5DEF456...": {
    "repo": "other/better-model",
    "commit": "f6e5d4c3b2a1...",
    "cdn_url": "https://other-cdn.com/files",
    "revealed_at_block": 12430,
    "round": "404-gen-comp1-r1"
  }
}
```

| Field | Type | Description |
|-------|------|-------------|
| `repo` | string | GitHub repository in format `owner/repo` |
| `commit` | string | Git commit SHA |
| `cdn_url` | string | CDN URL for downloading generated GLB files |
| `revealed_at_block` | int | Block number when submission was revealed |
| `round` | string | Full round identifier (competition name and round number) |

**Writer:** `submission-collector` during OPEN stage.

### `rounds/{round}/seed.json`

Random seed for deterministic generation and validation.

```json
{
  "seed": 847291
}
```

**Writer:** `submission-collector` at the end of OPEN stage.

### `rounds/{round}/prompts.txt`

URLs of image prompts selected for this round, one per line.

```
https://cdn.example.com/prompts/car.png
https://cdn.example.com/prompts/chair.png
https://cdn.example.com/prompts/mug.png
```

**Writer:** `submission-collector` at the end of OPEN stage.

### `rounds/{round}/builds.json`

Container build status per miner.

```json
{
  "5ABC123...": {
    "repo": "user/3d-gen-model",
    "commit": "a1b2c3d4e5f6...",
    "revealed_at_block": 12425,
    "tag": "a1b2c3d-404-gen-comp1-r1",
    "status": "success",
    "docker_image": "ghcr.io/user/3d-gen-model:a1b2c3d-404-gen-comp1-r1"
  },
  "5DEF456...": {
    "repo": "other/better-model",
    "commit": "f6e5d4c3b2a1...",
    "revealed_at_block": 12430,
    "tag": "f6e5d4c-404-gen-comp1-r1",
    "status": "failure",
    "docker_image": null
  }
}
```

| Field | Type | Description |
|-------|------|-------------|
| `repo` | string | GitHub repository in format `owner/repo` |
| `commit` | string | Git commit SHA |
| `revealed_at_block` | int | Block number when submission was revealed |
| `tag` | string | Docker image tag |
| `status` | string | One of: `pending`, `in_progress`, `success`, `failure`, `timed_out`, `not_found` |
| `docker_image` | string \| null | Docker image URL if build succeeded |

**Writer:** `generation-orchestrator` during DUELS stage.

### `rounds/{round}/require_audit.json`

Miners requiring output verification. Written when a miner becomes a candidate winner.

```json
[
  {
    "hotkey": "5ABC123...",
    "critical_prompts": ["car", "chair"]
  }
]
```

| Field | Type | Description |
|-------|------|-------------|
| `hotkey` | string | Miner hotkey requiring verification |
| `critical_prompts` | array | Prompt stems that were decisive in matches (stricter tolerance) |

**Writer:** `judge-service` during DUELS stage.

### `rounds/{round}/generation_audits.json`

Verification results for miners.

```json
{
  "5ABC123...": {
    "hotkey": "5ABC123...",
    "outcome": "passed",
    "checked_prompts": 20,
    "failed_prompts": 1,
    "failed_critical": 0,
    "generation_time": 45.2,
    "reason": ""
  },
  "5DEF456...": {
    "hotkey": "5DEF456...",
    "outcome": "rejected",
    "checked_prompts": 20,
    "failed_prompts": 5,
    "failed_critical": 2,
    "generation_time": 120.5,
    "reason": "Too many critical prompt mismatches"
  }
}
```

| Field | Type | Description |
|-------|------|-------------|
| `hotkey` | string | Miner hotkey |
| `outcome` | string | One of: `pending`, `passed`, `rejected` |
| `checked_prompts` | int | Prompts regenerated so far |
| `failed_prompts` | int | Non-critical prompts that failed verification |
| `failed_critical` | int | Critical prompts that failed verification |
| `generation_time` | float \| null | Trimmed median generation time in seconds |
| `reason` | string | Rejection reason if applicable |

**Writer:** `generation-orchestrator` during DUELS stage.

### `rounds/{round}/matches_matrix.csv`

All match results in CSV format.

```csv
left,right,margin
leader,5ABC123...,0.15
leader,5DEF456...,-0.10
5ABC123...,5DEF456...,0.05
```

| Column | Description |
|--------|-------------|
| `left` | Defender hotkey (or `leader` for the base leader) |
| `right` | Challenger hotkey |
| `margin` | Match margin: positive = challenger wins, negative = defender wins |

**Writer:** `judge-service` during DUELS stage.

### `rounds/{round}/winner.json`

Final round winner.

```json
{
  "hotkey": "5ABC123..."
}
```

**Writer:** `judge-service` at the end of DUELS stage.

## Per-Miner State

Each miner has their own directory: `rounds/{round_number}/{hotkey}/`

### `rounds/{round}/{hotkey}/submitted.json`

Generations submitted by the miner, downloaded from their CDN. Maps prompt stem to generation result.

```json
{
  "car": {
    "glb": "https://r2.example.com/rounds/1/5ABC123/car.glb",
    "png": "https://r2.example.com/rounds/1/5ABC123/car.png",
    "generation_time": 0,
    "size": 1048576,
    "attempts": 0,
    "distance": 0.0
  },
  "chair": {
    "glb": "https://r2.example.com/rounds/1/5ABC123/chair.glb",
    "png": "https://r2.example.com/rounds/1/5ABC123/chair.png",
    "generation_time": 0,
    "size": 524288,
    "attempts": 0,
    "distance": 0.0
  }
}
```

| Field | Type | Description |
|-------|------|-------------|
| `glb` | string \| null | CDN URL to GLB file |
| `png` | string \| null | CDN URL to rendered preview |
| `generation_time` | float | Generation time in seconds (0 for submitted files) |
| `size` | int | File size in bytes |
| `attempts` | int | Download attempts |
| `distance` | float | DINOv3 distance to regenerated output (0 until verified) |

**Writer:** `submission-collector` during DOWNLOADING stage.

### `rounds/{round}/{hotkey}/generated.json`

Regenerated outputs for verification. Same format as `submitted.json`.

```json
{
  "car": {
    "glb": "https://r2.example.com/rounds/1/5ABC123/generated/car.glb",
    "png": "https://r2.example.com/rounds/1/5ABC123/generated/car.png",
    "generation_time": 45.2,
    "size": 1048576,
    "attempts": 1,
    "distance": 0.02
  }
}
```

The `distance` field is populated after comparing with the submitted version using DINOv3 embeddings.

**Writer:** `generation-orchestrator` during DUELS stage.

### `rounds/{round}/{hotkey}/duels_{opponent}.json`

Match report for a specific matchup.

```json
{
  "left": "5DEF456...",
  "right": "5ABC123...",
  "score": 2,
  "margin": 0.10,
  "duels": [
    {
      "name": "car",
      "prompt": "https://cdn.example.com/prompts/car.png",
      "left_glb": "https://r2.example.com/rounds/1/5DEF456/car.glb",
      "left_png": "https://r2.example.com/rounds/1/5DEF456/car.png",
      "right_glb": "https://r2.example.com/rounds/1/5ABC123/car.glb",
      "right_png": "https://r2.example.com/rounds/1/5ABC123/car.png",
      "winner": "right",
      "issues": ""
    },
    {
      "name": "chair",
      "prompt": "https://cdn.example.com/prompts/chair.png",
      "left_glb": "https://r2.example.com/rounds/1/5DEF456/chair.glb",
      "left_png": "https://r2.example.com/rounds/1/5DEF456/chair.png",
      "right_glb": "https://r2.example.com/rounds/1/5ABC123/chair.glb",
      "right_png": "https://r2.example.com/rounds/1/5ABC123/chair.png",
      "winner": "right",
      "issues": ""
    },
    {
      "name": "mug",
      "prompt": "https://cdn.example.com/prompts/mug.png",
      "left_glb": "https://r2.example.com/rounds/1/5DEF456/mug.glb",
      "left_png": "https://r2.example.com/rounds/1/5DEF456/mug.png",
      "right_glb": "https://r2.example.com/rounds/1/5ABC123/mug.glb",
      "right_png": "https://r2.example.com/rounds/1/5ABC123/mug.png",
      "winner": "left",
      "issues": ""
    }
  ]
}
```

| Field | Type | Description |
|-------|------|-------------|
| `left` | string | Defender hotkey |
| `right` | string | Challenger hotkey |
| `score` | int | Net score: +1 per win, -1 per loss, 0 per draw |
| `margin` | float | Normalized margin: score / total_duels |
| `duels` | array | Individual duel results |
| `duels[].name` | string | Prompt stem (identifier) |
| `duels[].prompt` | string | URL to the prompt image |
| `duels[].left_glb` | string \| null | URL to defender's GLB model |
| `duels[].left_png` | string \| null | URL to defender's rendered preview |
| `duels[].right_glb` | string \| null | URL to challenger's GLB model |
| `duels[].right_png` | string \| null | URL to challenger's rendered preview |
| `duels[].winner` | string | One of: `left`, `right`, `draw`, `skipped` |
| `duels[].issues` | string | Issues detected by the judge |

**Writer:** `judge-service` during DUELS stage.

## File Write Order

```
FINALIZING (round N-1)
  └── rounds/{N}/schedule.json
  └── leader.json (append)
  └── state.json → OPEN

OPEN
  └── rounds/{N}/submissions.json
  └── rounds/{N}/seed.json
  └── rounds/{N}/prompts.txt
  └── state.json → MINER_GENERATION

MINER_GENERATION
  └── (miners upload to their CDNs)
  └── state.json → DOWNLOADING

DOWNLOADING
  └── rounds/{N}/{hotkey}/submitted.json
  └── state.json → DUELS

DUELS
  └── rounds/{N}/builds.json
  └── rounds/{N}/require_audit.json
  └── rounds/{N}/{hotkey}/generated.json
  └── rounds/{N}/generation_audits.json
  └── rounds/{N}/matches_matrix.csv
  └── rounds/{N}/{hotkey}/duels_*.json
  └── rounds/{N}/winner.json
  └── state.json → FINALIZING
```

## External Storage

GLB files and rendered PNGs are stored in R2 (Cloudflare). URLs in generation files reference this storage.

## Verification Pipeline

When a miner becomes a candidate winner:

1. `judge-service` writes their hotkey to `require_audit.json` with critical prompts
2. `generation-orchestrator` deploys the miner's Docker image to serverless GPU
3. `generation-orchestrator` regenerates all prompts with the round's seed
4. `generation-orchestrator` compares regenerated outputs to submitted ones using DINOv3
5. `generation-orchestrator` writes results to `generation_audits.json`
6. `judge-service` reads audit results and continues or discards the timeline

If verification fails, the timeline is discarded and alternative winners are evaluated.