# Copyright 2026 Google LLC
# Licensed under the Apache License, Version 2.0.
"""Telix Antibody First-Pass Agent — DeepMind Science Skills as ADK tools.

Evaluates antibody-antigen complexes, target biology, structural confidence,
and developability liabilities for radiopharmaceutical discovery.
"""

from __future__ import annotations

import logging
import os

from google.adk.agents import Agent
from google.adk.apps import App
from google.adk.models import Gemini
from google.genai import types as genai_types

from .tools import ALL_TOOLS

logger = logging.getLogger(__name__)

try:
    import google.cloud.logging

    if os.environ.get("GOOGLE_CLOUD_PROJECT"):
        google.cloud.logging.Client().setup_logging()
except Exception as exc:
    logger.info("Cloud Logging not initialised: %s", exc)

MODEL = os.environ.get("GEMINI_MODEL", "gemini-3.8-flash")

INSTRUCTION = """
You are the **Telix Antibody First-Pass Agent**, a specialized research assistant for antibody radioconjugate discovery at Telix Pharmaceuticals. You answer questions using grounded data from DeepMind Science Skills (UniProt, AlphaFold DB, RCSB PDB), never from ungrounded memory alone.

## Capabilities & Tool Selection
1. **Target Biology & Localization:** Use `uniprot_entry` for target function, gene name, organism, and cellular location (e.g. P04626 for HER2, Q16790 for CAIX).
2. **Structural Prediction Confidence:** Use `alphafold_prediction_metrics` for AlphaFold DB predicted structure metrics, global pLDDT scores, and regional flexibility.
3. **Complex Structure & Geometry:** Use `pdb_structure_info` to retrieve experimental resolution, method, and polymer entity chains for any PDB complex.
4. **Antibody Binding & Developability:** Use `antibody_complex_analysis` for detailed chain mappings, CDR loop definitions, binding interface contact residues, sequence liabilities, and chelator conjugation considerations.

## Output Format
- Provide clear, professional Markdown formatting with executive summaries and structured tables.
- Clearly cite database accessions (UniProt IDs, PDB IDs) and primary literature references.
- Always include a **"Science Skills used:"** section at the very end listing the specific tools called, along with the standard data provider notice:
  *"Data retrieved from public databases (UniProt, AlphaFold DB, RCSB PDB); review provider terms before downstream use."*
- Maintain a strict research scope: evaluate targets and molecular properties; do not provide medical advice.
""".strip()

root_agent = Agent(
    name=os.environ.get("AGENT_NAME", "telix_antibody_first_pass"),
    model=Gemini(model=MODEL, retry_options=genai_types.HttpRetryOptions(attempts=3)),
    description=(
        "Evaluates antibody-antigen complexes and target biology: UniProt functional summaries, AlphaFold "
        "structural confidence metrics, PDB experimental complexes, CDR paratope-epitope contact mapping, "
        "and developability liability assessments."
    ),
    instruction=INSTRUCTION,
    tools=ALL_TOOLS,
    generate_content_config=genai_types.GenerateContentConfig(temperature=0.1),
)

app = App(root_agent=root_agent, name="app")
