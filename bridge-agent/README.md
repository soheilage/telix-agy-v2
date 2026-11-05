# Telix Antibody First-Pass Agent (Module 4)

An ADK agent whose tools **wrap DeepMind Science Skills scripts** (UniProt, AlphaFold DB, RCSB PDB), deployed to
Vertex AI **Agent Runtime** (`europe-west4`) and registered in the Telix **Gemini Enterprise** app (`eu`).
It allows discovery, clinical, and regulatory colleagues to evaluate target biology, structural confidence,
and antibody complex developability directly from a conversational chat window—without requiring a local IDE.

```
bridge-agent/
├── app/
│   ├── agent.py                  root_agent: persona + tool list (gemini-3.8-flash)
│   ├── tools.py                  ADK function tools → science skill scripts
│   └── science_skills_runner.py  runs `uv run <skill>/scripts/<script> …` with rate limits
├── build.sh      scaffold (agents-cli) + overlay + vendor science-skills + Dockerfile patch + smoke test
├── deploy.sh     agents-cli deploy → Agent Runtime (EU)
├── publish.sh    agents-cli publish gemini-enterprise (ADK registration)
├── smoke_test.sh local + remote query
├── common.sh     loads .env, resolves PROJECT_NUMBER / GE resource name
└── .env.example
```

## How it works

```mermaid
flowchart LR
  GE[Gemini Enterprise<br/>Agents tab] -->|streamQuery| AR[Agent Runtime<br/>telix-antibody-first-pass]
  AR --> A[ADK root_agent<br/>gemini-3.8-flash]
  A --> T1[uniprot_entry]
  A --> T2[alphafold_prediction_metrics]
  A --> T3[pdb_structure_info]
  A --> T4[antibody_complex_analysis]
  T1 & T2 & T3 & T4 -->|uv run script.py| S[(vendored<br/>science-skills)]
  S --> DB[(UniProtKB · AlphaFold DB · RCSB PDB)]
```

- **Grounded tools:** Cover the antibody first-pass workflow (target biology → structural confidence → 3D complex binding → developability liabilities & chelator pairing).
- **Execution:** Scripts run with `uv run` using their PEP 723 inline dependencies. `build.sh` ensures the container has `uv` and a pre-warmed cache.
- **Data residency:** Deployed to Agent Runtime in `europe-west4`; model inference on `location=eu` (`aiplatform.eu.rep.googleapis.com`); Gemini Enterprise app in `eu`.

## Build, deploy, publish

```bash
cp .env.example .env   # set PROJECT_ID, GE_APP_ID
./build.sh             # ~3–5 min; ends with a local smoke test
./deploy.sh            # ~5–10 min; deploys to Vertex AI Agent Runtime in europe-west4
./publish.sh           # registers in Gemini Enterprise with display name "Telix Antibody First-Pass"
./smoke_test.sh        # local + remote run of the demo question
```

## Demo question

> Summarize the binding interface and developability liabilities for the antibody in PDB 1N8Z targeting HER2. Include key contact regions and chelator conjugation considerations.
