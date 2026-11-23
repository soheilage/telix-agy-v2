#!/usr/bin/env bash
# Smoke-test the bridge agent locally (agents-cli run) and remotely (Agent Runtime streamQuery REST API).
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
source "${HERE}/common.sh"
export PATH="$HOME/.local/bin:$PATH"
cd "${HERE}/${AGENT_PROJECT}" || { echo "Run ./build.sh first"; exit 1; }
set -a; source app/.env; set +a

Q="${1:-Profile HER2 (gene ERBB2, UniProt P04626) as a radioligand target: function and cellular location, normal-tissue RNA expression (GTEx), protein expression and subcellular location (Human Protein Atlas), AlphaFold structural confidence, and the binding interface and developability liabilities of the antibody in PDB 1N8Z.}"

echo "== LOCAL: agents-cli run"
agents-cli run "${Q}"

[[ -f deployment_metadata.json ]] || { echo "(no deployment_metadata.json — remote test skipped)"; exit 0; }
RE="$(python3 -c 'import json;d=json.load(open("deployment_metadata.json"));print(d.get("remote_agent_runtime_id") or "")')"
[[ -n "${RE}" ]] || { echo "no remote_agent_runtime_id in deployment_metadata.json"; exit 0; }

echo; echo "== REMOTE: Agent Runtime ${RE}"
TOKEN="$(gcloud auth application-default print-access-token)"
REQ="$(python3 -c 'import json,sys; print(json.dumps({"class_method":"streaming_agent_run_with_events","input":{"request_json":json.dumps({"user_id":"smoke-test","message":{"role":"user","parts":[{"text":sys.argv[1]}]}})}}))' "${Q}")"
OUT="$(mktemp)"
curl -s -m 600 -N -X POST \
  -H "Authorization: Bearer ${TOKEN}" -H "x-goog-user-project: ${PROJECT_ID}" -H 'Content-Type: application/json' \
  "https://${REGION}-aiplatform.googleapis.com/v1/${RE}:streamQuery?alt=sse" -d "${REQ}" > "${OUT}"

python3 - "${OUT}" <<'PY'
import json, sys
tools, text = [], []
for line in open(sys.argv[1]):
    line = line.strip()
    if not line:
        continue
    try:
        d = json.loads(line)
    except json.JSONDecodeError:
        print(line[:500]); continue
    if "error" in d:
        print("ERROR:", json.dumps(d["error"])[:800]); continue
    for ev in d.get("events", [d]):
        for p in ev.get("content", {}).get("parts", []):
            if "function_call" in p:
                tools.append(f"{p['function_call']['name']} {json.dumps(p['function_call'].get('args'))}")
            if "function_response" in p:
                r = p["function_response"].get("response", {})
                tools.append(f"   -> {r.get('status')} {str(r.get('error') or '')[:120]}")
            if "text" in p:
                text.append(p["text"])
print("TOOL CALLS:"); print("\n".join(tools) or "(none)")
print("\nANSWER:\n" + "".join(text))
PY
rm -f "${OUT}"
