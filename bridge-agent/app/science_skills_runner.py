# Copyright 2026 Google LLC
# Licensed under the Apache License, Version 2.0.
"""Thin runner that executes vendored DeepMind Science Skills scripts with `uv run`.

The deployed agent calls the *same* scripts the Antigravity IDE uses, so rate limits,
retries and data-provider licensing behaviour are identical. Scripts carry PEP 723
inline dependencies, so `uv run` resolves them on first use (cached in UV_CACHE_DIR).
"""

from __future__ import annotations

import json
import os
import pathlib
import shutil
import subprocess
import tempfile
from typing import Any

# Location of the vendored skills (set by build.sh; falls back to common IDE install paths).
_CANDIDATES = [
    os.environ.get("SCIENCE_SKILLS_DIR", ""),
    str(pathlib.Path(__file__).parent / "science_skills" / "skills"),
    str(pathlib.Path.home() / ".agents" / "skills"),
]
SKILLS_DIR = next((pathlib.Path(p) for p in _CANDIDATES if p and pathlib.Path(p).is_dir()), None)

SCRIPT_TIMEOUT_S = int(os.environ.get("SCIENCE_SKILL_TIMEOUT", "120"))
MAX_RETURN_CHARS = int(os.environ.get("SCIENCE_SKILL_MAX_CHARS", "12000"))

_ENV = {
    **os.environ,
    "UV_CACHE_DIR": os.environ.get("UV_CACHE_DIR", "/tmp/uv-cache"),
    "UV_PYTHON_PREFERENCE": os.environ.get("UV_PYTHON_PREFERENCE", "only-system"),
    "UV_NO_PROGRESS": "1",
    "POLITE_HTTP_USER_AGENT": os.environ.get(
        "POLITE_HTTP_USER_AGENT", "telix-agy-workshop/2.0 (research; contact soheila@google.com)"
    ),
}


def _uv() -> str:
    for cand in (shutil.which("uv"), str(pathlib.Path.home() / ".local/bin/uv"), "/usr/local/bin/uv", "/bin/uv"):
        if cand and pathlib.Path(cand).exists():
            return cand
    raise RuntimeError("uv is not installed in this environment")


def skill_dir(skill: str) -> pathlib.Path:
    """Return the directory of a skill, accepting `chembl-database` or `chembl_database`."""
    if SKILLS_DIR is None:
        raise RuntimeError("Science Skills directory not found; set SCIENCE_SKILLS_DIR")
    for name in (skill, skill.replace("-", "_"), skill.replace("_", "-")):
        p = SKILLS_DIR / name
        if p.is_dir():
            return p
    raise FileNotFoundError(f"skill '{skill}' not found under {SKILLS_DIR}")


def list_skills() -> list[str]:
    if SKILLS_DIR is None:
        return []
    return sorted(p.name for p in SKILLS_DIR.iterdir() if (p / "SKILL.md").exists())


def read_skill_md(skill: str, max_chars: int = 8000) -> str:
    text = (skill_dir(skill) / "SKILL.md").read_text(encoding="utf-8")
    return text[:max_chars] + ("\n...[truncated]" if len(text) > max_chars else "")


def _truncate(obj: Any) -> Any:
    s = json.dumps(obj, ensure_ascii=False)
    if len(s) <= MAX_RETURN_CHARS:
        return obj
    return {"truncated": True, "preview": s[:MAX_RETURN_CHARS], "note": "Result truncated; refine the query."}


def run_script(
    skill: str,
    script: str,
    args: list[str],
    *,
    output_flag: str | None = "--output",
    output_suffix: str = ".json",
    parse_stdout_json: bool = False,
    truncate: bool = True,
) -> dict[str, Any]:
    """Run `<skill>/scripts/<script> args` and return a JSON-serialisable result.

    If `output_flag` is given, a temp file is appended as `<flag> <path>` and read back.
    If `parse_stdout_json` is True, stdout is parsed as JSON instead.
    If `truncate` is False the full payload is returned (for callers that slim it themselves).
    """
    sdir = skill_dir(skill)
    script_path = sdir / "scripts" / script
    if not script_path.exists():
        return {"status": "error", "error": f"script not found: {script_path}"}

    tmp = None
    cmd = [_uv(), "run", "--quiet", str(script_path), *args]
    if output_flag:
        fd, tmp = tempfile.mkstemp(suffix=output_suffix, prefix=f"{sdir.name}_")
        os.close(fd)
        cmd += [output_flag, tmp]

    try:
        proc = subprocess.run(
            cmd, cwd=str(sdir), env=_ENV, capture_output=True, text=True, timeout=SCRIPT_TIMEOUT_S, check=False
        )
    except subprocess.TimeoutExpired:
        return {"status": "error", "error": f"timeout after {SCRIPT_TIMEOUT_S}s", "command": " ".join(cmd)}

    result: dict[str, Any] = {
        "status": "success" if proc.returncode == 0 else "error",
        "skill": sdir.name,
        "command": " ".join(cmd),
        "stderr": proc.stderr[-2000:] if proc.returncode != 0 else "",
    }
    data: Any = None
    try:
        if tmp and pathlib.Path(tmp).exists() and pathlib.Path(tmp).stat().st_size > 0:
            with open(tmp, encoding="utf-8") as fh:
                data = json.load(fh) if output_suffix == ".json" else fh.read()
        elif parse_stdout_json and proc.stdout.strip():
            data = json.loads(proc.stdout)
        else:
            data = proc.stdout[-MAX_RETURN_CHARS:]
    except json.JSONDecodeError:
        data = proc.stdout[-MAX_RETURN_CHARS:]
    finally:
        if tmp:
            try:
                os.remove(tmp)
            except OSError:
                pass

    result["data"] = _truncate(data) if truncate else data
    return result
