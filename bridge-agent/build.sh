#!/usr/bin/env bash
# Build the Telix Target Intelligence Agent:
#   1. scaffold an ADK project with agents-cli (Agent Runtime target, EU region)
#   2. overlay our agent.py / tools.py / science_skills_runner.py
#   3. vendor google-deepmind/science-skills into app/science_skills/
#   4. make sure the Dockerfile has `uv` and a warm dependency cache
#   5. write app/.env, install deps, run a local smoke test
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
source "${HERE}/common.sh"

export PATH="$HOME/.local/bin:$PATH"
need uv; need agents-cli; need gcloud; need git

cd "${HERE}"

# 1. Scaffold --------------------------------------------------------------
if [[ -d "${AGENT_PROJECT}" ]]; then
  echo "== ${AGENT_PROJECT} exists; skipping scaffold (delete it to re-scaffold)"
else
  echo "== Scaffolding ${AGENT_PROJECT} (adk / agent_runtime / ${REGION} / prototype)"
  agents-cli scaffold create "${AGENT_PROJECT}" \
    --agent adk \
    --deployment-target agent_runtime \
    --region "${REGION}" \
    --prototype \
    --agent-guidance-filename GEMINI.md \
    --auto-approve
fi
cd "${AGENT_PROJECT}"

# 2. Overlay our code --------------------------------------------------------
echo "== Overlaying agent code"
[[ -f app/agent.py && ! -f app/agent.scaffolded.py.bak ]] && cp app/agent.py app/agent.scaffolded.py.bak
cp "${HERE}/app/agent.py" app/agent.py
cp "${HERE}/app/tools.py" app/tools.py
cp "${HERE}/app/science_skills_runner.py" app/science_skills_runner.py

# 3. Vendor science skills ---------------------------------------------------
if [[ -d app/science_skills/skills ]]; then
  echo "== science-skills already vendored"
else
  echo "== Vendoring google-deepmind/science-skills"
  REF_ARGS=(); [[ -n "${SCIENCE_SKILLS_REF:-}" ]] && REF_ARGS=(--branch "${SCIENCE_SKILLS_REF}")
  git clone --depth 1 "${REF_ARGS[@]}" https://github.com/google-deepmind/science-skills.git app/science_skills
  rm -rf app/science_skills/.git
fi
# keep only the skills we ship (smaller image); comment out to ship all
KEEP=(uniprot_database alphafold_database_fetch_and_analyze pdb_database gtex_database human_protein_atlas_database uv credentials)
for d in app/science_skills/skills/*/; do
  n="$(basename "$d")"
  keep=0; for k in "${KEEP[@]}"; do [[ "$n" == "$k" ]] && keep=1; done
  [[ $keep -eq 0 ]] && rm -rf "$d"
done
echo "   vendored skills: $(ls app/science_skills/skills | tr '\n' ' ')"

# 4. Dockerfile: uv + warm cache --------------------------------------------
if [[ -f Dockerfile ]]; then
  if ! grep -q 'astral-sh/uv\|install.sh | sh\|uv' Dockerfile; then
    echo "== Adding uv to Dockerfile"
    sed -i.bak '1a COPY --from=ghcr.io/astral-sh/uv:latest /uv /uvx /bin/' Dockerfile
  fi
  if ! grep -q 'science_skills_warm_cache' Dockerfile; then
    cat >> Dockerfile <<'EOF'

# --- science skills: warm the uv dependency cache so first tool call is fast (science_skills_warm_cache)
ENV UV_CACHE_DIR=/tmp/uv-cache UV_PYTHON_PREFERENCE=only-system SCIENCE_SKILLS_DIR=/app/app/science_skills/skills
RUN set -e; for s in /app/app/science_skills/skills/*/scripts/*.py; do \
      (cd "$(dirname "$s")/.." && uv run --quiet "$s" --help >/dev/null 2>&1 || true); done
EOF
  fi
  # the warm-cache RUN assumes the project is copied to /app; adjust if the scaffold uses another WORKDIR
  WD="$(grep -m1 '^WORKDIR' Dockerfile | awk '{print $2}' || true)"
  if [[ -n "${WD}" && "${WD}" != "/app" ]]; then
    sed -i.bak "s#/app/app/science_skills#${WD}/app/science_skills#g" Dockerfile
  fi
fi
# make sure vendored skills are not docker-ignored
if [[ -f .dockerignore ]] && grep -q '^app/science_skills' .dockerignore; then
  sed -i.bak '/^app\/science_skills/d' .dockerignore
fi

# 5. .env, deps, smoke test --------------------------------------------------
cat > app/.env <<EOF
GOOGLE_CLOUD_PROJECT=${PROJECT_ID}
GOOGLE_CLOUD_LOCATION=${MODEL_LOCATION}
GOOGLE_GENAI_USE_VERTEXAI=true
GEMINI_MODEL=${GEMINI_MODEL}
SCIENCE_SKILLS_DIR=$(pwd)/app/science_skills/skills
UV_CACHE_DIR=/tmp/uv-cache
EOF
echo "== Installing dependencies"
# Lock against PUBLIC PyPI regardless of any local uv mirror config (corporate/Google mirrors embed private
# URLs in uv.lock and the managed Agent Runtime image build cannot reach them -> "Connection refused").
UV_NO_CONFIG=1 UV_INDEX_URL=https://pypi.org/simple UV_DEFAULT_INDEX=https://pypi.org/simple uv lock --refresh >/dev/null
if awk '/airlock|uplink.goog|artifactregistry|internal/' uv.lock | head -1 | awk 'END{exit NR==0}'; then
  echo "   !! uv.lock still references a private index; fix your uv config (~/.config/uv/uv.toml) and re-run"; exit 1
fi
agents-cli install
uv add google-cloud-logging >/dev/null 2>&1 || true

echo "== Local smoke test (target profile exercising all six tools)"
set -a; source app/.env; set +a
agents-cli run "Profile HER2 (gene ERBB2, UniProt P04626) as a radioligand target: function and cellular location, normal-tissue RNA expression (GTEx), protein expression and subcellular location (Human Protein Atlas), AlphaFold structural confidence, and the binding interface and developability liabilities of the antibody in PDB 1N8Z. Then list the Science Skills used." || {
  echo "Smoke test failed — inspect the output above (common causes: ADC not set, model/region, egress)."; exit 1; }

echo
echo "BUILD OK → next: ./deploy.sh"
