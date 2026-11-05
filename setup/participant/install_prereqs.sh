#!/usr/bin/env bash
# Install participant prerequisites (everything except the Antigravity IDE and gcloud).
# Safe to re-run. Works on macOS / Linux / WSL2.
set -euo pipefail

echo "== uv (Python package manager used by agents-cli and Science Skills)"
if ! command -v uv >/dev/null 2>&1 && [[ ! -x "$HOME/.local/bin/uv" ]]; then
  curl -LsSf https://astral.sh/uv/install.sh | sh
fi
export PATH="$HOME/.local/bin:$PATH"
uv --version

echo "== Node.js LTS via nvm (only needed for 'npx skills add'; skip if you use the IDE Science plugin)"
if ! command -v node >/dev/null 2>&1; then
  curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.1/install.sh | bash
  export NVM_DIR="$HOME/.nvm"; # shellcheck disable=SC1091
  . "$NVM_DIR/nvm.sh"
  nvm install --lts
fi
node --version || true

echo "== google-agents-cli + ADK skills for Antigravity (requires >= 1.12)"
uv tool install --upgrade google-agents-cli      # pin to latest; a cached uvx can resolve an old 1.x
export PATH="$HOME/.local/bin:$PATH"
agents-cli --version
agents-cli setup || uvx google-agents-cli@latest setup   # registers the google-agents-cli-* skills globally
agents-cli info || true

echo "== DeepMind Science Skills"
echo "   Preferred: in Antigravity -> Customizations -> Build with Google -> Science -> Add"
echo "   Fallback (CLI agents / no plugin access):"
echo "     npx skills add google-deepmind/science-skills --yes"

echo "== PATH"
case ":$PATH:" in *":$HOME/.local/bin:"*) ;; *)
  echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$HOME/.bashrc"
  [[ -f "$HOME/.zshrc" ]] && echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$HOME/.zshrc"
  echo "   added ~/.local/bin to PATH in your shell rc";;
esac

echo
echo "Done. Now run: setup/participant/preflight.sh"
