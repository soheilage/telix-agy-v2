# Workspace rules for the Telix × Google Cloud Antigravity workshop

These rules apply to every agent conversation opened in this folder.

## Execution
- Commands that need credentials or the network (`gcloud`, `agents-cli`, `uv run …/scripts/*.py`, `npx`, `curl`)
  must run **outside the terminal sandbox** on the first attempt; do not retry sandboxed runs that exit 127.
- Prefer `agents-cli` and the DeepMind Science Skills scripts over hand-written API calls; follow each `SKILL.md`.
- When a command fails, show the error and fix it; do not silently switch approach.

## Google Cloud (EU data residency)
- Project: the active `gcloud` project. Agent Runtime region: `europe-west4`.
- Gemini inference location: `eu` (`GOOGLE_CLOUD_LOCATION=eu`). **Never use `global`.** Model: `gemini-3.8-flash`.
- Deploy agents with `--no-agent-identity --service-account <PROJECT_NUMBER>-compute@developer.gserviceaccount.com`.
- Gemini Enterprise app location: `eu`.

## Files & secrets
- Write generated reports to `reports/` and generated agent projects to the workspace root.
- Never write API keys into prompts, reports or git; keep them in `~/.env` or `app/.env` (both git-ignored).
- Record data-provider licence notices in `.licenses/` as the Science Skills instruct, and mention the skills used
  at the end of every scientific answer.

## Scope
- Scientific answers are for research/target-assessment use only; no medical advice to patients.
- Only public identifiers (gene symbols, UniProt accessions, compound names) may be sent to external databases.
