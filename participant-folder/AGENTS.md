# Workspace rules for the Telix × Google Cloud Antigravity workshop

These rules apply to every agent conversation opened in this folder.

## Execution
- Commands that need credentials or the network (`gcloud`, `uv run …/scripts/*.py`, `npx`, `curl`) must run
  **outside the terminal sandbox** on the first attempt; do not retry sandboxed runs that exit 127.
- Always use the DeepMind Science Skills scripts for scientific data (UniProt, AlphaFold DB, InterPro, STRING,
  GTEx, Human Protein Atlas, ChEMBL, PubChem, ClinicalTrials.gov, PDB, PyMOL, literature). Follow each
  `SKILL.md`. Never answer scientific data questions from memory unless the user explicitly asks you to.
- When a command fails, show the error and fix it; do not silently switch approach.
- Multi-database tasks may take several minutes; keep going and report progress briefly.

## Google Cloud (EU data residency)
- Project: the active `gcloud` project. Region: `europe-west4`.
- Gemini inference location: `eu` (`GOOGLE_CLOUD_LOCATION=eu`). **Never use `global`.** Model: `gemini-3.8-flash`.

## Files & secrets
- Write every generated report, table or image to `reports/`. Use clear file names (e.g.
  `reports/psma_target_profile.md`). Save PyMOL images as PNG and the `.pse` session next to them.
- Never write API keys into prompts, reports or files other than `~/.env` (git-ignored).
- Record data-provider licence notices in `.licenses/` as the Science Skills instruct.
- **End every scientific answer with the list of Science Skills used.**

## Scope
- Scientific answers are for research/target-assessment use only; no medical advice to patients.
- Only public identifiers (gene symbols, UniProt accessions, compound names, PDB IDs) may be sent to external
  databases. If the user pastes what looks like a proprietary sequence or structure, stop and ask before
  sending it anywhere.
- Never invent sequences, accessions, SMILES or citations. If a source cannot be retrieved, say so.

## Interaction style
- When the user runs `/grill-me` or asks you to interview them, ask multiple-choice questions one at a time
  and update the plan artifact at the end.
- When the user runs `/plan`, write the plan as an artifact and wait for approval before executing.
