#!/usr/bin/env bash
# Participant pre-flight check (Day 2, researcher edition).
# Run from the workshop folder, or let the Antigravity agent run it.
# Prints PASS / WARN / FAIL lines. Exit 1 if anything required FAILs.
#
# Day 2 needs NO Google Cloud credentials on the laptop: Gemini runs through your Antigravity sign-in,
# the Science Skills query public databases, and Module 4 uses Gemini Enterprise in the browser.
set -uo pipefail
export PATH="$HOME/.local/bin:$PATH"

FAIL=0
ok()   { echo "PASS  $1"; }
bad()  { echo "FAIL  $1"; FAIL=1; }
warn() { echo "WARN  $1"; }

echo "== Workspace"
[[ -f AGENTS.md ]] && ok "opened the workshop folder (AGENTS.md found)" || bad "AGENTS.md not found — add the telix-antigravity-workshop folder as a Project in Antigravity and start the conversation from it"
mkdir -p reports && ok "reports/ ready"

echo; echo "== Tools"
if command -v uv >/dev/null; then ok "uv $(uv --version)"; else
  warn "uv missing — installing (needed by the Science Skills)"
  curl -LsSf https://astral.sh/uv/install.sh | sh >/dev/null 2>&1 && command -v uv >/dev/null && ok "uv installed" || bad "uv install failed: https://docs.astral.sh/uv/"
fi
command -v python3 >/dev/null && ok "python $(python3 --version 2>&1)" || bad "python3 missing"
command -v curl >/dev/null && ok "curl available" || bad "curl missing"

echo; echo "== DeepMind Science Skills"
if [[ -f "$HOME/.gemini/config/plugins/science/skills/pdb_database/SKILL.md" ]] || [[ -f "$HOME/.gemini/config/plugins/science/skills/uniprot_database/SKILL.md" ]]; then
  ok "Science plugin installed (~/.gemini/config/plugins/science/skills)"
elif ls -d "$HOME"/.agents/skills/*uniprot* "$PWD"/.agents/skills/*uniprot* 2>/dev/null | head -1 | awk 'END{exit NR==0}'; then
  ok "Science Skills installed via npx"
else
  bad "Science Skills not found — in Antigravity: Customizations -> Marketplace -> Build with Google -> Science -> + (then re-run)"
fi

echo; echo "== Scientific databases reachable (public, no login)"
for HOST in rest.uniprot.org/uniprotkb/P04626.json alphafold.ebi.ac.uk/api/prediction/P04626 files.rcsb.org/download/1N8Z.cif data.rcsb.org/rest/v1/core/entry/1N8Z; do
  curl -sf -o /dev/null -m 20 "https://${HOST}" && ok "${HOST}" || warn "${HOST} unreachable (proxy / egress) — tell a facilitator"
done

echo
if [[ ${FAIL} -eq 0 ]]; then echo "READY FOR THE WORKSHOP"; else echo "PLEASE FIX THE FAIL ITEMS ABOVE (ask the Antigravity agent, or raise your hand)"; exit 1; fi
