# Telix × Google Cloud — Agentic AI Workshop Day 2
# Research with an AI Agent in Antigravity

A hands-on, 85-minute workshop for **Telix Pharmaceuticals** researchers, informatics, and clinical colleagues.
Participants explore how to use the **Google Antigravity IDE** and **DeepMind Science Skills** to accelerate
biologics and radiopharmaceutical discovery:

1. **Characterize targets:** Fetch biological function and AlphaFold structural prediction metrics (Module 1).
2. **Interactive alignment:** Use conversational planning (`/plan` and `/grill-me`) to define assessment criteria (Module 2).
3. **Examine antibody complexes:** Inspect binding interfaces in 3D (PDB 1N8Z) and scan for developability liabilities and chelator conjugation residues (Module 3).
4. **Enterprise enablement:** Query the deployed *Telix Target Intelligence* agent directly from **Gemini Enterprise** (Module 4).

> **Data Residency:** All cloud resources operate in the European Union (`europe-west4`; Gemini endpoint `location=eu`; Gemini Enterprise `eu`).
> **Model:** `gemini-3.8-flash`.

---

## Deploy the agent (Telix Target Intelligence)

> **Versions.** This branch (`main`) holds the upgraded agent (six tools: UniProt, GTEx, Human Protein Atlas, AlphaFold DB, RCSB PDB, antibody-complex analysis): **Telix Target Intelligence** (`telix-target-intel`).
> Branch `antibody-first-pass-v1` holds the initial agent: **Telix Antibody First-Pass** (`telix-antibody-first-pass`).
> The two agents are separate Agent Runtime instances and separate Gemini Enterprise registrations, so
> deploying one **adds** an agent and does not replace the other. Both can run in the same project.

Partner engineers: follow [`PARTNER_DEPLOY.md`](PARTNER_DEPLOY.md) top to bottom. In short, from `bridge-agent/`:

```bash
cp .env.example .env   # set PROJECT_ID and GE_APP_ID
./build.sh             # scaffolds telix-target-intel/, vendors the Science Skills, runs a local smoke test
./deploy.sh            # deploys to Vertex AI Agent Runtime (europe-west4)
./publish.sh           # registers "Telix Target Intelligence" in the Gemini Enterprise app
./smoke_test.sh        # local + remote test, prints the tool calls
```

## Agenda (85 min)

| # | Module | Time | Focus |
| :-- | :-- | :--: | :-- |
| 0 | **Getting started** | 5 min | Open workshop workspace, preflight verification, model setup |
| 1 | **Know the target** | 10 min | Target biology (UniProt) & structural confidence (AlphaFold DB) for HER2 |
| 2 | **Plan before acting** | 10 min | Requirements interview (`/grill-me`), plan generation, and approval |
| 3 | **The antibody in 3D & developability** | 25 min | **3A:** 3D complex binding contacts (1N8Z) & PyMOL render<br>**3B:** Chemical liabilities & payload conjugation check |
| 4 | **From laptop to team** | 20 min | **4.1:** Test *Telix Target Intelligence* in Gemini Enterprise<br>**4.2:** Tool architecture code walkthrough<br>**4.3:** Antibody Design Workbench video showcase |
| 5 | **Wrap-up & governance** | 10 min | Translation to Telix CAIX / PSMA programs, governance & next steps |

The participant guide for this session is available on Google Docs:
**[Telix Workshop Day 2 — Research with an AI Agent in Antigravity](https://docs.google.com/document/d/1rx1f1WPLS8imBBQudLCe2baeYJ0MmigFreLMOvr5Lo4/edit)**

---

## Repository Layout

```
.
├── README.md                 ← Overview & workshop agenda (you are here)
├── FACILITATOR_GUIDE.md      ← Pre-provisioning checklist, dry-run instructions & run sheet
├── PARTNER_DEPLOY.md         ← Step-by-step runbook for deploying the bridge agent
├── AGENTS.md                 ← Always-on rules for the Antigravity agent
├── participant-folder/       ← Participant workspace distributed as a zip
│   ├── AGENTS.md             ← Workspace rules (EU residency, citations)
│   ├── PROMPTS.md            ← Copy-paste prompts for all exercises
│   ├── setup/preflight.sh    ← Environment readiness check
│   └── reports/              ← Destination for generated reports and images
├── setup/facilitator/        ← Project provisioning & verification scripts (00–05)
└── bridge-agent/             ← Module 4: Telix Target Intelligence ADK Agent
```

---

## Preparing the Participant Package

To distribute the clean workspace to participants via Google Drive:

```bash
cd participant-folder && zip -r ../telix-antigravity-workshop.zip . -x '.DS_Store' && cd ..
```

Participants download and extract `telix-antigravity-workshop.zip` to their `Desktop`, then open the folder in Antigravity.
