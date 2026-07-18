#!/usr/bin/env bash
#
# Validate every Mermaid diagram in the repository.
#
# Covers both diagram sources:
#   1. standalone .mmd files
#   2. ```mermaid fenced blocks embedded in Markdown
#
# Requires mermaid-cli (mmdc) on PATH:
#   npm install --global @mermaid-js/mermaid-cli
#
# Reports every failure rather than stopping at the first, and always
# prints the renderer error instead of discarding it.

set -uo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WORK_DIR="$(mktemp -d)"
trap 'rm -rf "${WORK_DIR}"' EXIT

if ! command -v mmdc >/dev/null 2>&1; then
  echo "[error] mmdc not found. Install with: npm install --global @mermaid-js/mermaid-cli" >&2
  exit 1
fi

# Headless Chrome cannot use its sandbox inside most CI containers.
PUPPETEER_CONFIG="${WORK_DIR}/puppeteer.json"
cat > "${PUPPETEER_CONFIG}" <<'JSON'
{ "args": ["--no-sandbox", "--disable-gpu", "--disable-dev-shm-usage"] }
JSON

failures=0
checked=0

validate() {
  local source_label="$1"
  local diagram_file="$2"

  checked=$((checked + 1))
  local render_log="${WORK_DIR}/render.log"

  if mmdc --puppeteerConfigFile "${PUPPETEER_CONFIG}" \
          -i "${diagram_file}" \
          -o "${WORK_DIR}/out.svg" > "${render_log}" 2>&1; then
    echo "[pass] ${source_label}"
  else
    echo "[fail] ${source_label}" >&2
    sed 's/^/        /' "${render_log}" >&2
    failures=$((failures + 1))
  fi
}

echo "[info] Validating standalone .mmd files"
while IFS= read -r -d '' file; do
  validate "${file#"${ROOT_DIR}/"}" "${file}"
done < <(find "${ROOT_DIR}" -name '*.mmd' -not -path '*/.git/*' -print0 | sort -z)

echo "[info] Validating fenced mermaid blocks in Markdown"
while IFS= read -r -d '' file; do
  # Split each ```mermaid ... ``` block into its own file for rendering.
  block_count=0
  in_block=0
  current=""

  while IFS= read -r line || [[ -n "${line}" ]]; do
    if [[ ${in_block} -eq 0 && "${line}" =~ ^[[:space:]]*\`\`\`mermaid[[:space:]]*$ ]]; then
      in_block=1
      block_count=$((block_count + 1))
      current="${WORK_DIR}/block-${block_count}.mmd"
      : > "${current}"
      continue
    fi

    if [[ ${in_block} -eq 1 && "${line}" =~ ^[[:space:]]*\`\`\`[[:space:]]*$ ]]; then
      in_block=0
      validate "${file#"${ROOT_DIR}/"} (mermaid block ${block_count})" "${current}"
      continue
    fi

    if [[ ${in_block} -eq 1 ]]; then
      printf '%s\n' "${line}" >> "${current}"
    fi
  done < "${file}"

  if [[ ${in_block} -eq 1 ]]; then
    echo "[fail] ${file#"${ROOT_DIR}/"}: unterminated \`\`\`mermaid block" >&2
    failures=$((failures + 1))
  fi
done < <(find "${ROOT_DIR}" -name '*.md' -not -path '*/.git/*' -not -path '*/node_modules/*' -print0 | sort -z)

echo
echo "[info] Checked ${checked} diagram(s); ${failures} failure(s)"

if [[ ${failures} -gt 0 ]]; then
  exit 1
fi
