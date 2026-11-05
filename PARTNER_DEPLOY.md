# Partner Deployment Runbook — Telix Antibody First-Pass Agent

**Audience:** the partner engineer preparing the Telix Google Cloud project for the *Agentic AI with Google
Antigravity* workshop. Follow this file top to bottom from the **repository root**; it uses only
`setup/facilitator/` and `bridge-agent/`.

**Outcome when you are done:** in the Telix Gemini Enterprise app, the **Agents** tab shows
*Telix Antibody First-Pass*, and it answers the test question in step 7 with a *"Science Skills used"* footer.

Estimated hands-on time: **60–90 minutes** (most of it waiting for the build and the deploy).

## What you will use

| Path | Purpose |
| :-- | :-- |
| `PARTNER_DEPLOY.md` | This runbook — follow it top to bottom |
| `setup/facilitator/00_vars.sh … 05_verify.sh` | Idempotent scripts that enable APIs, grant IAM, create buckets and verify the project |
| `bridge-agent/` | The agent: ADK code (`app/`), `build.sh` → `deploy.sh` → `publish.sh` → `smoke_test.sh`, `.env.example` |
| [`FACILITATOR_GUIDE.md`](FACILITATOR_GUIDE.md) | Background and full known-issues list. Only needed if something in this runbook fails |

## What the agent is

An **ADK** (Agent Development Kit) agent running on **Vertex AI Agent Runtime** in `europe-west4`. Its tools call
the open-source **DeepMind Science Skills** scripts (UniProt, AlphaFold DB, RCSB PDB), which are vendored into
the container at build time. Model inference uses `gemini-3.8-flash` on the **EU jurisdictional endpoint**
(`location=eu`). The agent is registered in the Telix **Gemini Enterprise** app (location `eu`) so workshop
participants can chat with it without an IDE.

Nothing in this package deploys a custom model. Gemini is consumed as an API.

## Step 0 — What you need before starting

### 0.1 Access (ask the Telix cloud admin)

On the workshop project you need **one** of:

- `roles/owner`, **or**
- all of: `roles/serviceusage.serviceUsageAdmin`, `roles/resourcemanager.projectIamAdmin`,
  `roles/aiplatform.admin`, `roles/discoveryengine.admin`, `roles/storage.admin`, `roles/iam.serviceAccountUser`

You also need a **Gemini Enterprise user licence** on the Telix GE app so you can open it and test the agent
(Cloud Console → Gemini Enterprise → Licences).

### 0.2 Information to collect

Write these down; you will put them in `.env` in step 3.

| Item | Where to find it | Example |
| :-- | :-- | :-- |
| `PROJECT_ID` | Cloud Console → project selector | `telix-agent-workshop` |
| Gemini Enterprise **app ID** | Cloud Console → Gemini Enterprise → Apps → the Telix app → *ID* column | `telix-gemini-enterprise` |
| GE app **location** | Same page — must be **`eu`** | `eu` |

The project number and the full GE resource name are resolved automatically by the scripts.

### 0.3 Tools on your machine (macOS or Linux; on Windows use WSL2)

```bash
# Google Cloud CLI — https://cloud.google.com/sdk/docs/install
gcloud auth login
gcloud auth application-default login
gcloud config set project <PROJECT_ID>

# uv (Python runner used by the Science Skills) — https://docs.astral.sh/uv/
curl -LsSf https://astral.sh/uv/install.sh | sh

# google-agents-cli >= 1.12 (builds / deploys / publishes ADK agents)
uv tool install google-agents-cli
agents-cli --version

# git and python3 must also be present
git --version && python3 --version
```

**Note:** `uv tool install` places `agents-cli` in `~/.local/bin`. The scripts add that to `PATH` themselves, but
your shell may need `export PATH="$HOME/.local/bin:$PATH"`.

### 0.4 Network

Your machine and the Agent Runtime container need outbound HTTPS to `*.googleapis.com`, `pypi.org`,
`files.pythonhosted.org`, `github.com`, and the scientific hosts (`rest.uniprot.org`, `gtexportal.org`,
`www.proteinatlas.org`, `www.ebi.ac.uk`, `pubchem.ncbi.nlm.nih.gov`, `clinicaltrials.gov`). If the project has
VPC Service Controls or egress restrictions, raise this with the Telix admin **before** step 5.

## Step 1 — Verify the project (5 min)

Even if the project was provisioned by hand, run the verifier first. It is read-only.

```bash
cd setup/facilitator
export PROJECT_ID=<PROJECT_ID>
export GE_APP_ID=<GE app ID>        # only if different from telix-gemini-enterprise
./05_verify.sh
```

Read the output:

- **All `PASS` and `ALL REQUIRED CHECKS PASSED`** → go to step 3.
- **Any `FAIL`** → go to step 2 and run the matching script, then re-run `05_verify.sh`.

The important checks are: the eight APIs, the two EU buckets, the Discovery Engine service agent having
`roles/aiplatform.user` (without it Gemini Enterprise cannot call the agent → 403), the GE app existing in
`eu`, and `gemini-3.8-flash` returning **200** on the `eu` endpoint.

## Step 2 — Provision what is missing (10 min, only if step 1 failed)

Run only the scripts for the failed checks. All scripts are idempotent (safe to re-run).

```bash
cd setup/facilitator
export PROJECT_ID=<PROJECT_ID>

./01_enable_apis.sh          # APIs (aiplatform, discoveryengine, agentregistry, storage, cloudbuild, …)
./04_buckets.sh              # gs://<PROJECT_ID>-adk-staging and gs://<PROJECT_ID>-workshop in europe-west4
./03_service_agents.sh       # service-agent IAM (run ~1 min after 01 so the compute SA exists)
./05_verify.sh               # must be green before continuing
```

**Participants' IAM (optional for you).** If the Telix admin has not yet granted participant roles, copy
`participants.txt.example` to `participants.txt`, add one email per line, and run `./02_iam_participants.sh`.
Licences (Gemini Enterprise, Antigravity) must still be assigned in the Console — the script reminds you.

**Gemini Enterprise app missing?** Create it in the Console: Gemini Enterprise → Apps → Create app → name
*Telix - Gemini Enterprise*, app ID `telix-gemini-enterprise`, **location `eu`**, no data stores. Then re-run
`05_verify.sh`.

## Step 3 — Configure the agent (2 min)

```bash
cd bridge-agent
cp .env.example .env
```

Edit `.env` and set:

```bash
PROJECT_ID=<PROJECT_ID>
STAGING_BUCKET=gs://<PROJECT_ID>-adk-staging
GE_APP_ID=<GE app ID>              # default telix-gemini-enterprise
```

Leave the rest at their defaults (`REGION=europe-west4`, `MODEL_LOCATION=eu`, `GEMINI_MODEL=gemini-3.8-flash`,
`GE_LOCATION=eu`, `RUNTIME_SA` empty). `.env` is git-ignored; never commit it.

## Step 4 — Build (5 min)

```bash
./build.sh
```

What it does: scaffolds an ADK project `telix-target-intel/` with `agents-cli`, overlays `app/agent.py`,
`app/tools.py`, `app/science_skills_runner.py`, clones the Science Skills into `app/science_skills/`, patches
the Dockerfile so the container has `uv`, writes `app/.env`, locks dependencies against public PyPI, and runs
**a local smoke test** (`agents-cli run` with the demo question).

Success looks like: a printed answer about CAIX that ends with the Science Skills it used. If the local run
fails, check `telix-target-intel/app/.env` and that `gcloud auth application-default login` was done.

## Step 5 — Deploy to Agent Runtime (5–10 min)

```bash
./deploy.sh
```

The script runs `agents-cli deploy` with `--region europe-west4 --no-confirm-project --no-agent-identity
--service-account <PROJECT_NUMBER>-compute@developer.gserviceaccount.com`.

**Why `--no-agent-identity`?** The EU data-resident Gemini endpoint currently rejects the per-agent identity
principal with `401 UNAUTHENTICATED`. Running as the project compute service account works; script `03`
grants it the needed roles. Do not change this.

Success looks like: `deployment_metadata.json` printed with a `remote_agent_runtime_id`, then `DEPLOY OK`.
If you passed `--no-wait`, check progress with `cd telix-target-intel && agents-cli deploy --status`.

## Step 6 — Publish to Gemini Enterprise (1 min)

```bash
./publish.sh
```

Registers the deployed agent in the GE app (registration type `adk`, display name *Telix Antibody First-Pass*).
Re-running updates the existing registration. Success looks like `PUBLISH OK`.

## Step 7 — Test and hand over (10 min)

### 7.1 Automated

```bash
./smoke_test.sh
```

Runs the demo question locally **and** against the deployed Agent Runtime, printing the tool calls it made
(expect `uniprot_entry`, `alphafold_prediction_metrics`, `pdb_structure_info`, `antibody_complex_analysis`)
and the final answer.

### 7.2 In Gemini Enterprise (what participants will see)

1. Open the GE app URL (Cloud Console → Gemini Enterprise → Apps → the Telix app → *Open*).
2. **New chat → Agents tab → select *Telix Antibody First-Pass*.**
3. Ask:

> Summarize the binding interface and developability liabilities for the antibody in PDB 1N8Z targeting HER2. Include key contact regions and chelator conjugation considerations.

4. Expect an answer in 1–2 minutes with sections for target summary, complex structure, CDR definitions,
   binding interface contact residues, developability liabilities, and a *"Science Skills used"* footer.
   **Take a screenshot** — the facilitator keeps it as a backup for the live demo.

### 7.3 Hand-over note to the workshop facilitator

Send the facilitator:

- The GE app URL and confirmation that *Telix Antibody First-Pass* is visible in the Agents tab
- The screenshot from 7.2
- The `05_verify.sh` output (all green)
- The quota check result from step 8
- `telix-target-intel/deployment_metadata.json` (contains the Agent Runtime resource name)

## Step 8 — Quota check (5 min)

The workshop has ~20 participants sending prompts in bursts; the agent and the participants' IDE sessions
share the project's Gemini capacity. Check **three** things:

### 8.1 Gemini request capacity on the `eu` endpoint

Gemini models on Vertex AI use **Dynamic Shared Quota**: there is normally no per-project limit to raise, but
there can be project-level caps. In the Console:

1. **IAM & Admin → Quotas & System Limits**.
2. Filter: *Service* = `Vertex AI API`; *Metric* contains `generate_content` (or search for
   `gemini-3.8-flash`); *Dimension location* = `eu`.
3. Look at the *requests per minute* and *tokens per minute* values. **Target:** requests/min ≥ 60 ×
   participants (e.g. ≥ 1 200 for 20 people). If a value is lower than that, select the row → **Edit quota**
   → request the increase with the justification *"Customer workshop on <date>, ~20 concurrent users"*.
   Requests typically take 1–2 business days — do this at least a week ahead.
4. If the row is not editable (shared quota), note the current value for the facilitator; the workshop plan
   staggers prompts if 429s appear.

### 8.2 Agent Runtime instances

Same page, filter *Metric* contains `reasoning_engine` for region `europe-west4`. **Target:** ≥ participants
+ 2 (participants may deploy their own agent in the take-home track). Request an increase if lower.

### 8.3 Live probe

```bash
cd setup/facilitator && ./05_verify.sh | grep -A1 "Model availability"
```

Must show `gemini-3.8-flash served on the EU data-resident endpoint (location=eu)`. Report HTTP codes other
than 200 to the facilitator.

## Troubleshooting (most common first)

| Symptom | Fix |
| :-- | :-- |
| `05_verify.sh`: *Discovery Engine SA lacks roles/aiplatform.user* | `./03_service_agents.sh` |
| `05_verify.sh`: *GE app not found* | App ID or location wrong — must be location `eu`; it lists existing apps so you can copy the right ID into `.env` |
| `05_verify.sh`: model probe `404` on `eu` | Gemini 3.x is only on `eu` / `global`; a 404 on `eu` means the model name is wrong or the API is not enabled. Never switch to `global` (breaks EU residency) |
| `build.sh`: *missing required tool* | Install per step 0.3; `export PATH="$HOME/.local/bin:$PATH"` |
| `build.sh`: *uv.lock still references a private index* | Your `uv` config points at a private PyPI mirror; remove `~/.config/uv/uv.toml` or set `UV_NO_CONFIG=1`, re-run |
| `deploy.sh`: *Service account …-compute@… does not exist* | `compute.googleapis.com` was enabled seconds ago; wait 1 min, re-run `03_service_agents.sh`, then `deploy.sh` |
| `deploy.sh`: timeout / build error | Open the Cloud Build / Agent Runtime log link printed by `agents-cli`; `agents-cli deploy --status` |
| Deployed agent returns `401` from `aiplatform.eu.rep.googleapis.com` | Deployed with agent identity by mistake; re-run `./deploy.sh` (it uses `--no-agent-identity`) |
| `publish.sh`: *lists no apps* / permission error | App not in `eu`, or your account lacks `discoveryengine.admin` |
| GE chat returns 403 when calling the agent | Discovery Engine service agent missing `roles/aiplatform.user` → `./03_service_agents.sh` |
| GE answer has no *"Science Skills used"* footer | The chat is using another agent — New chat → Agents → select *Telix Target Intelligence* |
| Tool calls fail inside the container (SSL / connection refused) | Egress restriction on the project (step 0.4) |

More in [`FACILITATOR_GUIDE.md`](FACILITATOR_GUIDE.md) §9.

## Re-deploying after a change

```bash
cd bridge-agent
# code change in app/ → rebuild overlay and redeploy
rm -rf telix-target-intel && ./build.sh && ./deploy.sh && ./publish.sh
```

## Data-residency summary (for Telix governance questions)

| Component | Location |
| :-- | :-- |
| Agent Runtime (agent, sessions, traces) | `europe-west4` |
| Gemini inference (`gemini-3.8-flash`) | `location=eu` → `aiplatform.eu.rep.googleapis.com` (never `global`) |
| Gemini Enterprise app | `eu` multi-region |
| Buckets | `europe-west4` |
| Science Skills data sources | Public databases (UniProt, GTEx, ChEMBL, …); only public identifiers are sent |
