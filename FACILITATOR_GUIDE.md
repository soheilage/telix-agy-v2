# Facilitator Guide — Technical Requirements & Pre-provisioning

This document lists **everything that must exist before participants arrive**. The 2-hour agenda has no slack
for installation or access problems. Work through the checklist top to bottom; the scripts in
`setup/facilitator/` automate the GCP parts.

## 0. EU data-residency architecture (summary for data-governance review)

| Component | Location | Data in scope | Residency |
| :-- | :-- | :-- | :-- |
| **Agent Runtime** (deployed ADK agents, sessions, memory, traces) | `europe-west4` | prompts, tool inputs/outputs, session history | EU ✅ |
| **Gemini inference** (`gemini-3.8-flash`) | `location=eu` → `aiplatform.eu.rep.googleapis.com` (EU jurisdictional endpoint) | prompts and model responses | EU ✅ — single EU regions return 404 for Gemini 3.x; **`global` is never used** |
| **Gemini Enterprise app** | `eu` multi-region | end-user chats, agent registrations | EU ✅ |
| **Cloud Storage** (staging + M1 bucket) | `europe-west4` | agent build artefacts, exercise files | EU ✅ |
| **Cloud Logging / Trace** | project default (`global` buckets) | logs, spans — message content capture is **off** (`ADK_CAPTURE_MESSAGE_CONTENT_IN_SPANS=false`) | configure a `europe-west4` log bucket if required |
| **Antigravity IDE / Agent Platform licence** | Google-managed | IDE prompts and workspace context sent to Gemini via the user's Agent Platform licence | governed by Telix's Agent Platform / Gemini terms — confirm regional processing with the account team |
| **DeepMind Science Skills data sources** (UniProt, AlphaFold DB, GTEx, HPA, ChEMBL, PubChem, ClinicalTrials.gov …) | public, non-Google, mostly US/UK-hosted | **only public identifiers** (gene symbols, UniProt accessions, compound names) leave the tenant | not EU — acceptable because no Telix data is sent; participants are told not to paste proprietary sequences/structures |
| Runtime identity of deployed agents | `<PROJECT_NUMBER>-compute@developer.gserviceaccount.com` | — | the per-agent *agent identity* is **not** used (rejected by the `eu` endpoint) |

> Verified in dry run (`eg-telix`, 2026-10-28): end-to-end query from Gemini Enterprise → Agent Runtime
> (`europe-west4`) → `gemini-3.8-flash` @ `eu` → Science Skills tools, no `global` endpoint involved.

---

## 1. Roles & who does what

| Party | Responsibility |
| :-- | :-- |
| **Telix Cloud Admin** (Org/Project Owner) | Creates the workshop project, links billing, grants the facilitator the roles in §3.1, assigns Gemini Enterprise & Antigravity licences |
| **Workshop facilitator** (Google / partner) | Runs `setup/facilitator/*.sh`, creates the Gemini Enterprise app, pre-deploys the bridge agent, performs the dry run |
| **Telix IT / network** | Endpoint software approval (Antigravity IDE, `uv`, Node.js), egress allow-list (§6), proxy CA certificates |
| **Participants** | Install the IDE with the Science plugin, sign in to `gcloud`, unzip the participant folder from Drive, run `setup/preflight.sh` from it. IT/informatics colleagues doing Appendix A additionally clone this repo and run `setup/participant/preflight.sh` |

---

## 2. Timeline

| When | Action |
| :-- | :-- |
| T-10 days | Project created, billing linked, facilitator roles granted, licences requested, egress allow-list request filed |
| T-7 days | Run `00`–`05` facilitator scripts; create Gemini Enterprise app; confirm `gemini-3.8-flash` in `europe-west4` |
| T-5 days | Build & deploy the bridge agent (`bridge-agent/build.sh`, `deploy.sh`, `publish.sh`; runbook: `PARTNER_DEPLOY.md`); build the participant zip from `participant-folder/` and upload it to Drive |
| T-3 days | **Full dry run of Modules 0–4 as a participant** on a Telix-managed laptop, plus Appendix A (ADK build/deploy) |
| T-2 days | Participants install Antigravity IDE and run `setup/preflight.sh`; collect failures |
| T-1 day | Re-run `05_verify.sh`; confirm quotas |
| Day | Facilitator signed in 30 min early; bridge agent visible in Gemini Enterprise |

---

## 3. Google Cloud project

Create **one dedicated project** under Telix's organisation (e.g. `telix-agent-workshop`), billing attached.
All resources live in the EU.

| Setting | Value |
| :-- | :-- |
| Vertex AI / Agent Runtime region | `europe-west4` |
| Gemini model | `gemini-3.8-flash` |
| **Model location** (`GOOGLE_CLOUD_LOCATION` / `MODEL_LOCATION`) | **`eu`** — EU jurisdictional, data-resident multi-region endpoint (`aiplatform.eu.rep.googleapis.com`). Verified: `gemini-3.8-flash` 200 OK there. |
| Staging bucket | `gs://<PROJECT_ID>-adk-staging` in `europe-west4` |
| Workshop bucket (M1 exercise) | `gs://<PROJECT_ID>-workshop` in `europe-west4` |
| Gemini Enterprise app | location `eu`, e.g. app id `telix-gemini-enterprise` |

> [!IMPORTANT]
> **Model location finding (dry run in `eg-telix`, Oct 2026):** Gemini 3.x models return HTTP 404 from every
> *single* EU region (`europe-west1/2/3/4/…`) **and** from `us-central1` — regional Gemini endpoints are not where
> Gemini 3.x is served. They are served on the **`global`** endpoint (no residency guarantee) and on the
> **`eu` jurisdictional endpoint** (`location=eu`, host `aiplatform.eu.rep.googleapis.com`), which keeps
> inference inside the EU. Latest Flash verified on `eu`: **`gemini-3.8-flash`** (also 3.6 and 3.5; `3.8-flash-lite`
> not available). ADK/GenAI SDK picks the `eu.rep` host automatically when `GOOGLE_CLOUD_LOCATION=eu`.
> **Use `eu`; never `global` for Telix.** Agent Runtime, sessions and Gemini Enterprise remain in `europe-west4` / `eu`.
> Deploy with `--no-agent-identity --service-account <PROJECT_NUMBER>-compute@developer.gserviceaccount.com`
> (the default per-agent identity gets 401 from the `eu.rep` endpoint). Participants' M2 deploy prompt includes this.

### 3.1 Roles for the **facilitator** (needed to run the scripts)

- `roles/serviceusage.serviceUsageAdmin`
- `roles/resourcemanager.projectIamAdmin`
- `roles/aiplatform.admin`
- `roles/discoveryengine.admin`
- `roles/storage.admin`
- `roles/iam.serviceAccountUser`

(or simply `roles/owner` on the workshop project)

### 3.2 APIs — `setup/facilitator/01_enable_apis.sh`

```
aiplatform.googleapis.com          # Vertex AI / Agent Platform / Agent Runtime
discoveryengine.googleapis.com     # Gemini Enterprise
agentregistry.googleapis.com       # Agent Registry (publish)
storage.googleapis.com
cloudbuild.googleapis.com
artifactregistry.googleapis.com
logging.googleapis.com
cloudtrace.googleapis.com
iam.googleapis.com
cloudresourcemanager.googleapis.com
serviceusage.googleapis.com
```

### 3.3 Roles for **participants** — `setup/facilitator/02_iam_participants.sh`

Put participant emails in `setup/facilitator/participants.txt` (one per line). Each gets:

| Role | Why |
| :-- | :-- |
| `roles/aiplatform.user` | create/deploy/query Agent Runtime, call Gemini |
| `roles/discoveryengine.editor` | register agents in the Gemini Enterprise app |
| `roles/storage.objectAdmin` on the two buckets | staging uploads, M1 exercise |
| `roles/iam.serviceAccountUser` | deploy with the default compute SA |
| `roles/logging.viewer`, `roles/cloudtrace.user` | inspect logs/traces in Agent Platform |
| `roles/serviceusage.serviceUsageConsumer` | quota project usage |

Plus, outside IAM:

- A **Gemini Enterprise** user licence (Cloud Console → Gemini Enterprise → Licences).
- An **Antigravity / Agent Platform** licence ("Agent Platform – Pay as you go" is selected during IDE sign-in).

### 3.4 Service agents — `setup/facilitator/03_service_agents.sh`

| Service account | Role | Why |
| :-- | :-- | :-- |
| `service-<PROJECT_NUMBER>@gcp-sa-discoveryengine.iam.gserviceaccount.com` | `roles/aiplatform.user` | Gemini Enterprise must be able to call the agent on Agent Runtime |
| `service-<PROJECT_NUMBER>@gcp-sa-aiplatform.iam.gserviceaccount.com` | `roles/aiplatform.serviceAgent` (auto) | Agent Runtime builds/serves containers |
| `service-<PROJECT_NUMBER>@gcp-sa-aiplatform-re.iam.gserviceaccount.com` | `roles/aiplatform.reasoningEngineServiceAgent` | Agent Runtime builds/serves the container |
| `<PROJECT_NUMBER>-compute@developer.gserviceaccount.com` | `roles/aiplatform.user`, `roles/logging.logWriter`, `roles/cloudtrace.agent` | **runtime identity of deployed agents** (`agents-cli deploy --no-agent-identity --service-account …`); requires `compute.googleapis.com` enabled first |
| *Agent identity* `principal://agents.global.org-<ORG>.system.id.goog/…/reasoningEngines/<ID>` | auto-granted when `--agent-identity` (agents-cli default) | **Do not use with `location=eu`**: the EU jurisdictional model endpoint returned `401 UNAUTHENTICATED` for this principal in the dry run; the compute SA works |

### 3.5 Quotas

Check in **IAM & Admin → Quotas** for `europe-west4`:

- Vertex AI *Online prediction requests per minute* for `gemini-3.8-flash` — ≥ 60 × participants
- Vertex AI *Reasoning Engine* count — ≥ participants + 2
- Cloud Build concurrent builds — default (10) is fine; deploys are staggered

---

## 4. Gemini Enterprise app

1. Cloud Console → **Gemini Enterprise** → **Apps** → **Create app**.
2. Name **Telix - Gemini Enterprise**, app ID `telix-gemini-enterprise`, company name **Telix Pharmaceuticals**, **location `eu`**, no data stores needed.
3. Activate the trial/subscription; assign licences to all participants and the facilitator.
4. Record the full resource name for `publish.sh` and the modules:
   `projects/<PROJECT_NUMBER>/locations/eu/collections/default_collection/engines/telix-gemini-enterprise`
5. Verify a participant can open the app URL and see the **Agents** tab.

---

## 5. Participant workstations

| Requirement | Notes |
| :-- | :-- |
| OS | macOS 13+, Windows 11 (WSL2 recommended for shell steps) or Linux |
| **Antigravity IDE** | <https://antigravity.google/>; sign in with the Telix account; **Science plugin** enabled — tick *Science* on the "Build with Google" page of the first-run onboarding, or later via *Customizations → Build with Google → Science → Add* |
| `gcloud` CLI | authenticated (`gcloud auth login` + `gcloud auth application-default login`), default project set |
| Python 3.11+ and **`uv`** | `curl -LsSf https://astral.sh/uv/install.sh \| sh` |
| **Node.js LTS** | needed only if Science Skills are installed via `npx` instead of the IDE plugin |
| `google-agents-cli` | `uvx google-agents-cli setup` (also registers the `google-agents-cli-*` skills in Antigravity) |
| Git | to clone this repo |
| Corporate proxy | if SSL-inspecting, export `SSL_CERT_FILE`, `REQUESTS_CA_BUNDLE`, `NODE_EXTRA_CA_CERTS` |

`setup/participant/install_prereqs.sh` installs everything above except the IDE and `gcloud`;
`setup/participant/preflight.sh` verifies it.

---

## 6. Network egress allow-list (HTTPS/443)

Google:
`*.googleapis.com`, `antigravity.google`, `*.antigravity.google`, `accounts.google.com`, `oauth2.googleapis.com`,
`storage.googleapis.com`, `pypi.org`, `files.pythonhosted.org`, `astral.sh`, `github.com`, `objects.githubusercontent.com`,
`registry.npmjs.org`

Scientific data sources used in M3/M4:

| Host | Skill |
| :-- | :-- |
| `rest.uniprot.org` | uniprot-database |
| `alphafold.ebi.ac.uk` | alphafold-database |
| `www.ebi.ac.uk` | interpro-database |
| `string-db.org` | string-database |
| `gtexportal.org` | gtex-database |
| `www.proteinatlas.org` | human-protein-atlas-database |
| `www.ebi.ac.uk/chembl` | chembl-database |
| `pubchem.ncbi.nlm.nih.gov` | pubchem-database |
| `clinicaltrials.gov` | clinical-trials-database |
| `api.openalex.org`, `www.ebi.ac.uk/europepmc` | literature skills (take-aways) |
| `gnomad.broadinstitute.org`, `eutils.ncbi.nlm.nih.gov` | gnomad / clinvar (take-aways) |

Agent Runtime containers also need outbound internet to the same scientific hosts (default allowed unless
VPC-SC / egress controls are applied to the project).

---

## 7. Pre-deploy the bridge agent (M4 demo)

```bash
cd bridge-agent
cp .env.example .env            # fill PROJECT_ID etc. (or export the variables)
./build.sh                      # scaffolds with agents-cli, overlays app/, vendors science-skills
./deploy.sh                     # agents-cli deploy → Agent Runtime (5–10 min)
./publish.sh                    # registers in the Gemini Enterprise app
./smoke_test.sh                 # one local + one remote query
```

Keep the terminal output; you will show the generated `app/tools.py` during M4.

---

## 8. Dry run (T-3 days) — pass criteria

> Reference dry run (project `eg-telix`, 2026-10-28, agents-cli 1.12.0): scripts 01–05 ✅ · `build.sh` ✅ ·
> `deploy.sh` → Agent Runtime `europe-west4` in ~5 min ✅ · remote query with GTEx + ChEMBL tool calls ✅ ·
> `publish.sh` → EU Gemini Enterprise app ✅ · model `gemini-3.8-flash` @ `location=eu` ✅ with compute-SA identity (see §3).

- [ ] IDE signs in with a Telix account; Science plugin enabled; `setup/preflight.sh` in the participant folder ends with `READY FOR THE WORKSHOP`
- [ ] `05_verify.sh` model probe: `gemini-3.8-flash` on `location=eu` → 200
- [ ] Module 1–2 prompts (UniProt task, `/grill-me`-style interview → plan → proceed) complete on Flash Low
- [ ] Module 3 T2, T4, T5 prompts complete with the Science plugin (T2 ~2 min, T4 ~7 min); T1 and T3 reports pre-generated for the facilitator to show
- [ ] Bridge agent answers "Profile CAIX as a radioligand target" from the Gemini Enterprise **Agents** tab with a "Science Skills used" footer
- [ ] Appendix A: scaffold → build → playground → `agents-cli deploy` (< 12 min) → `publish gemini-enterprise` into the EU app works with `gemini-3.8-flash` @ `eu`
- [ ] `setup/facilitator/05_verify.sh` is all green

---

## 9. Known issues & fixes

| Symptom | Fix |
| :-- | :-- |
| `Session not found` / SDK version conflicts on deploy | ensure `google-cloud-aiplatform >= 1.129.0`; `uv lock --upgrade` |
| Deploy timeout | check Cloud Build / Agent Runtime logs link printed by `agents-cli deploy`; `agents-cli deploy --status` |
| `agents-cli deploy: no such option --staging-bucket` | agents-cli ≥ 1.12 stages the build itself — do not pass a staging bucket (the bucket is still used by participants in M1) |
| `ImportError: cannot import name 'app' from 'app.agent'` | the scaffold expects `app = App(root_agent=…, name="app")` exported from `agent.py` (bridge-agent/app/agent.py already does this) |
| `Service account …-compute@developer… does not exist` | enable `compute.googleapis.com` (script 01) and wait ~1 min before script 03 |
| REST calls return `403 … requires a quota project` | add header `x-goog-user-project: <PROJECT_ID>` and use an ADC token (`gcloud auth application-default print-access-token`) — scripts already do |
| Deployed agent returns `401 UNAUTHENTICATED` from `aiplatform.eu.rep.googleapis.com` | agent was deployed with the default *agent identity*; redeploy with `--no-agent-identity --service-account <compute SA>` |
| Image build fails: `Failed to download … airlock-proxy / Connection refused` | `uv.lock` was generated on a machine with a private PyPI mirror; regenerate with `UV_NO_CONFIG=1 UV_INDEX_URL=https://pypi.org/simple uv lock --refresh` (build.sh does this) |
| `agents-cli` version < 1.12 | `uv tool install --upgrade google-agents-cli` (older versions lack `--auto-approve`, `--no-confirm-project`) |
| GE cannot call agent (403) | Discovery Engine service agent lacks `roles/aiplatform.user` (script 03) |
| Science skill fails with SSL error | corporate proxy — export CA bundle variables (§5) |
| Preflight/`gcloud` fails with `exit code 127` inside Antigravity | the agent ran the command in its sandbox; it usually retries unsandboxed — otherwise ask it to "run outside the sandbox" |
| Science Skill scripts exit 127 on first try, then succeed | the IDE ran them sandboxed; the repo's `AGENTS.md` rule tells the agent to run unsandboxed — make sure participants opened the **repo folder** as the workspace |
| `Error: API error … daily-cloudcode-pa.googleapis.com … timed out` mid-task | transient Antigravity backend timeout; the agent retries by itself — wait, do not re-send the prompt |
| `TPM quota exhausted` in IDE | wait 1 min and retry; keep model on **Flash (Low)** |
| `uv` not found inside Agent Runtime container | `build.sh` patches the Dockerfile; re-run it |
| `publish` lists no apps | app created in wrong location — must be `eu` and the user needs `discoveryengine.editor` |

---

## 10. Day-of checklist

- [ ] Participant Guide (Google Doc) + Gemini Enterprise app open in tabs; `participant-folder` zip link in Drive ready
- [ ] Bridge agent published and answering; backup screenshot of the Module 4.1 answer at hand
- [ ] Pre-generated T1 (`psma_target_profile.md`) and T3 (`psma_ligands.md`) reports ready to show in Module 3.7
- [ ] Facilitator terminal: `gcloud config set project <PROJECT_ID>`; `05_verify.sh` green
- [ ] Timer visible; remind participants to start T4 right after T2 so it runs in the background
