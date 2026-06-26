#!/usr/bin/env bash
# memory-search.sh — ranked search across the Brain's memory sources
#
# Implements Tier 2 of the Memory Retrieval Protocol (v0.1).
# Spec: 01-Projects/portable-brain/specs/memory-retrieval-protocol.md
#
# This is the on-demand fallback when loaded context (Tier 1) doesn't
# have what the user is asking about. Returns ranked snippets with dates
# so the LLM can reference past content and the user gets sources.
#
# Author: Portable Brain v0.8
# Version: 0.1.0

set -euo pipefail

# ----------------------------------------------------------------------
# Defaults
# ----------------------------------------------------------------------
MAX_RESULTS=5
FORMAT="markdown"          # markdown | json | simple
SOURCE="all"               # all | memory | daily | crm | projects | observations | inbox
SINCE=""                   # YYYY-MM-DD, empty = no date filter
VERBOSE=0
SNIPPET_CHARS=240
QUERY=""

# Source paths (relative to vault root)
PATH_MEMORY="06-Agent/workspace/memory"
PATH_MEMORY_LONG="06-Agent/workspace/memory.md"
PATH_OBSERVATIONS="06-Agent/workspace/observations.md"
PATH_DAILY="07-Systems/goals/daily"
PATH_CRM="07-Systems/CRM/contacts"
PATH_PROJECTS="01-Projects"
PATH_INBOX="00-Inbox"

# ----------------------------------------------------------------------
# Vault root detection
# ----------------------------------------------------------------------
detect_vault_root() {
  local d="$PWD"
  while [ "$d" != "/" ]; do
    if [ -f "$d/CLAUDE.md" ] && [ -d "$d/06-Agent" ]; then
      echo "$d"
      return 0
    fi
    d=$(dirname "$d")
  done
  return 1
}

# ----------------------------------------------------------------------
# Cross-platform helpers (macOS BSD vs GNU)
# ----------------------------------------------------------------------
get_mtime() {
  # Returns file modification time as epoch seconds.
  # Try GNU first (Linux), fall back to BSD (macOS).
  # NOTE: order matters — on Linux, `stat -f` would be misinterpreted as
  # --file-system and produce garbage output.
  local result
  result=$(stat -c "%Y" -- "$1" 2>/dev/null)
  if [ -n "$result" ] && [[ "$result" =~ ^[0-9]+$ ]]; then
    echo "$result"
    return
  fi
  result=$(stat -f "%m" "$1" 2>/dev/null)
  if [ -n "$result" ] && [[ "$result" =~ ^[0-9]+$ ]]; then
    echo "$result"
    return
  fi
  return 1
}

date_to_epoch() {
  # Convert YYYY-MM-DD to epoch seconds. GNU first, BSD fallback.
  local result
  result=$(date -d "$1" "+%s" 2>/dev/null)
  if [ -n "$result" ] && [[ "$result" =~ ^[0-9]+$ ]]; then
    echo "$result"
    return
  fi
  result=$(date -j -f "%Y-%m-%d" "$1" "+%s" 2>/dev/null)
  if [ -n "$result" ] && [[ "$result" =~ ^[0-9]+$ ]]; then
    echo "$result"
    return
  fi
  return 1
}

# ----------------------------------------------------------------------
# Usage
# ----------------------------------------------------------------------
usage() {
  cat <<'EOF'
Usage: memory-search.sh "query terms" [options]

Ranked search across Brain memory sources. Returns top N snippets with dates.

Options:
  --source <s>     all | memory | daily | crm | projects | observations | inbox  (default: all)
  --since <date>   YYYY-MM-DD — only files modified after this date
  --format <fmt>   markdown | json | simple  (default: markdown)
  --max <N>        max results to return  (default: 5)
  --verbose        return up to 10 results
  --help, -h       show this message

Examples:
  memory-search.sh "Mariano HubSpot"
  memory-search.sh "Chirripó training" --source daily --since 2026-03-01
  memory-search.sh "dashboards" --format json --max 10
EOF
}

# ----------------------------------------------------------------------
# Parse args
# ----------------------------------------------------------------------
while [[ $# -gt 0 ]]; do
  case "$1" in
    --source) SOURCE="$2"; shift 2 ;;
    --since)  SINCE="$2"; shift 2 ;;
    --format) FORMAT="$2"; shift 2 ;;
    --max)    MAX_RESULTS="$2"; shift 2 ;;
    --verbose) VERBOSE=1; MAX_RESULTS=10; SNIPPET_CHARS=360; shift ;;
    --help|-h) usage; exit 0 ;;
    *)
      if [ -z "$QUERY" ]; then
        QUERY="$1"
      else
        QUERY="$QUERY $1"
      fi
      shift
      ;;
  esac
done

if [ -z "$QUERY" ]; then
  echo "Error: query required" >&2
  usage >&2
  exit 1
fi

# Check ripgrep availability
if ! command -v rg >/dev/null 2>&1; then
  echo "Error: ripgrep (rg) is required but not installed." >&2
  echo "  macOS: brew install ripgrep" >&2
  echo "  Linux: apt install ripgrep / dnf install ripgrep" >&2
  exit 1
fi

# Detect vault root
VAULT_ROOT=$(detect_vault_root) || {
  echo "Error: Not inside a Brain vault (no CLAUDE.md + 06-Agent/ found in current dir or parents)" >&2
  exit 1
}
cd "$VAULT_ROOT"

# ----------------------------------------------------------------------
# Build source file list
# ----------------------------------------------------------------------
build_source_list() {
  local include_paths=()
  case "$SOURCE" in
    all)
      [ -d "$PATH_MEMORY" ]      && include_paths+=("$PATH_MEMORY")
      [ -f "$PATH_MEMORY_LONG" ] && include_paths+=("$PATH_MEMORY_LONG")
      [ -f "$PATH_OBSERVATIONS" ] && include_paths+=("$PATH_OBSERVATIONS")
      [ -d "$PATH_DAILY" ]       && include_paths+=("$PATH_DAILY")
      [ -d "$PATH_CRM" ]         && include_paths+=("$PATH_CRM")
      [ -d "$PATH_PROJECTS" ]    && include_paths+=("$PATH_PROJECTS")
      [ -d "$PATH_INBOX" ]       && include_paths+=("$PATH_INBOX")
      ;;
    memory)
      [ -d "$PATH_MEMORY" ]      && include_paths+=("$PATH_MEMORY")
      [ -f "$PATH_MEMORY_LONG" ] && include_paths+=("$PATH_MEMORY_LONG")
      ;;
    daily)        [ -d "$PATH_DAILY" ]  && include_paths+=("$PATH_DAILY") ;;
    crm)          [ -d "$PATH_CRM" ]    && include_paths+=("$PATH_CRM") ;;
    projects)     [ -d "$PATH_PROJECTS" ] && include_paths+=("$PATH_PROJECTS") ;;
    observations) [ -f "$PATH_OBSERVATIONS" ] && include_paths+=("$PATH_OBSERVATIONS") ;;
    inbox)        [ -d "$PATH_INBOX" ]  && include_paths+=("$PATH_INBOX") ;;
    *)
      echo "Error: unknown source '$SOURCE'" >&2
      exit 1
      ;;
  esac
  printf "%s\n" "${include_paths[@]}"
}

# ----------------------------------------------------------------------
# Source priority weight (higher = more relevant)
# ----------------------------------------------------------------------
source_weight() {
  local file="$1"
  [ -z "$file" ] && { echo 1; return; }
  case "$file" in
    "$PATH_MEMORY"/*)        echo 5 ;;
    "$PATH_OBSERVATIONS")    echo 4 ;;
    "$PATH_DAILY"/*)         echo 4 ;;
    "$PATH_CRM"/*)           echo 3 ;;
    "$PATH_PROJECTS"/*)      echo 3 ;;
    */README.md)             echo 3 ;;
    "$PATH_MEMORY_LONG")     echo 2 ;;
    "$PATH_INBOX"/*)         echo 1 ;;
    *)                       echo 1 ;;
  esac
}

# ----------------------------------------------------------------------
# Age helpers
# ----------------------------------------------------------------------
file_age_days() {
  local file="$1"
  [ -z "$file" ] && { echo 999; return; }
  local now_epoch
  now_epoch=$(date "+%s")

  # Prefer date encoded in filename for memory/daily files (more accurate than mtime)
  local basename
  basename=$(basename "$file" .md)
  if [[ "$basename" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]]; then
    local file_epoch
    file_epoch=$(date_to_epoch "$basename" 2>/dev/null)
    if [ -n "$file_epoch" ]; then
      echo $(( (now_epoch - file_epoch) / 86400 ))
      return
    fi
  fi

  # Fallback to mtime
  local mtime
  mtime=$(get_mtime "$file")
  [ -z "$mtime" ] && { echo 999; return; }
  echo $(( (now_epoch - mtime) / 86400 ))
}

format_age() {
  local days="$1"
  if   [ "$days" -le 0 ]; then echo "today"
  elif [ "$days" -eq 1 ]; then echo "yesterday"
  elif [ "$days" -lt 7 ]; then echo "$days days ago"
  elif [ "$days" -lt 30 ]; then echo "$((days / 7)) week(s) ago"
  elif [ "$days" -lt 365 ]; then echo "$((days / 30)) month(s) ago"
  else echo "$((days / 365)) year(s) ago"
  fi
}

# Bucketed age penalty (no bc dependency)
age_penalty() {
  local days="${1:-0}"
  # Defensive: ensure we have a number
  [[ "$days" =~ ^[0-9]+$ ]] || days=0
  if   [ "$days" -le 1 ]; then echo 0
  elif [ "$days" -le 7 ]; then echo 1
  elif [ "$days" -le 30 ]; then echo 2
  elif [ "$days" -le 90 ]; then echo 3
  elif [ "$days" -le 365 ]; then echo 4
  else echo 5
  fi
}

# ----------------------------------------------------------------------
# Score a file: count distinct query terms matched (1 point each) + bonus
# ----------------------------------------------------------------------
score_file() {
  local file="$1"
  local query="$2"
  local distinct=0
  local bonus=0
  for term in $query; do
    local n
    # grep -c writes "0" to stdout with exit 1 when no matches;
    # capture exit separately so we don't end up with "0\n0".
    n=$(grep -ci -- "$term" "$file" 2>/dev/null) || true
    # Ensure n is a single integer (defensive)
    n=${n%%[!0-9]*}
    n=${n:-0}
    if [ "$n" -gt 0 ]; then
      distinct=$((distinct + 1))
      [ "$n" -gt 3 ] && n=3
      bonus=$((bonus + n))
    fi
  done
  # Distinct terms weighted 3x heavier than raw occurrences
  echo $((distinct * 3 + bonus))
}

# ----------------------------------------------------------------------
# Extract snippet around first match
# ----------------------------------------------------------------------
extract_snippet() {
  local file="$1"
  local query="$2"
  local maxchars="$3"
  # Use the first query term to anchor the snippet
  local anchor
  anchor=$(echo "$query" | awk '{print $1}')
  local snippet
  snippet=$(grep -i -m 1 -B 1 -A 2 -- "$anchor" "$file" 2>/dev/null \
           | tr '\n' ' ' \
           | sed -e 's/  */ /g' -e 's/^ *//' -e 's/ *$//')
  [ -z "$snippet" ] && { echo "(no preview)"; return; }
  if [ "${#snippet}" -gt "$maxchars" ]; then
    snippet="${snippet:0:$maxchars}..."
  fi
  echo "$snippet"
}

# ----------------------------------------------------------------------
# Apply date filter (if --since set)
# ----------------------------------------------------------------------
filter_by_date() {
  if [ -z "$SINCE" ]; then cat; return; fi
  local since_epoch
  since_epoch=$(date_to_epoch "$SINCE") || {
    echo "Error: invalid --since date '$SINCE' (use YYYY-MM-DD)" >&2
    exit 1
  }
  while IFS= read -r file; do
    [ -z "$file" ] && continue
    local mtime
    mtime=$(get_mtime "$file")
    [ -n "$mtime" ] && [ "$mtime" -ge "$since_epoch" ] && echo "$file"
  done
}

# ----------------------------------------------------------------------
# Main: gather, score, rank, output
# ----------------------------------------------------------------------

# 1. Resolve include paths
INCLUDE_PATHS=$(build_source_list)
if [ -z "$INCLUDE_PATHS" ]; then
  echo "Error: no source paths exist for --source $SOURCE" >&2
  exit 1
fi

# 2. Use ripgrep to find candidate files (multi-term: any match)
#    Building -e clauses for OR-search across all terms
RG_TERMS=()
for term in $QUERY; do
  RG_TERMS+=(-e "$term")
done

# Run ripgrep, capture only file paths
MATCHING_FILES=$(rg -l -i --no-messages \
  --glob '!**/.git/**' \
  --glob '!**/.claude/**' \
  --glob '!**/CONTEXT-PACK.md' \
  --glob '!**/AGENTS.md' \
  --glob '!**/SOUL.md' \
  --glob '!**/USER.md' \
  "${RG_TERMS[@]}" \
  $INCLUDE_PATHS 2>/dev/null \
  | filter_by_date \
  || true)

if [ -z "$MATCHING_FILES" ]; then
  TOTAL_MATCHES=0
else
  TOTAL_MATCHES=$(printf '%s\n' "$MATCHING_FILES" | awk 'NF { count++ } END { print count+0 }')
fi

if [ "$TOTAL_MATCHES" -eq 0 ]; then
  case "$FORMAT" in
    markdown)
      echo "## Memory search: \"$QUERY\""
      echo ""
      echo "No matches in indexable memory. The Brain may still have related context in loaded files (today's memory, briefings, recent weeks). Check loaded context, or refine the query."
      ;;
    json)    echo '{"query":"'"$QUERY"'","results":[],"total":0}' ;;
    simple)  echo "0" ;;
  esac
  exit 0
fi

# 3. Score and rank
RANKED=$(while IFS= read -r file; do
  [ -z "$file" ] && continue
  term_score=$(score_file "$file" "$QUERY")
  age_days=$(file_age_days "$file")
  weight=$(source_weight "$file")
  penalty=$(age_penalty "$age_days")
  composite=$((term_score * weight - penalty))
  printf "%05d|%d|%s\n" "$composite" "$age_days" "$file"
done <<< "$MATCHING_FILES" | sort -t'|' -k1 -rn | head -n "$MAX_RESULTS")

# 4. Output
case "$FORMAT" in
  markdown)
    echo "## Memory search: \"$QUERY\""
    echo ""
    rank=1
    while IFS='|' read -r score age_days file; do
      [ -z "$file" ] && continue
      age_str=$(format_age "$age_days")
      snippet=$(extract_snippet "$file" "$QUERY" "$SNIPPET_CHARS")
      echo "### $rank. \`$file\` ($age_str)"
      echo "> $snippet"
      echo ""
      rank=$((rank + 1))
    done <<< "$RANKED"
    if [ "$TOTAL_MATCHES" -gt "$MAX_RESULTS" ]; then
      omitted=$((TOTAL_MATCHES - MAX_RESULTS))
      echo "*$omitted more matches not shown. Pass --verbose for more, or refine the query.*"
    fi
    ;;
  json)
    printf '{\n  "query": "%s",\n  "results": [\n' "$QUERY"
    rank=1
    if [ -z "$RANKED" ]; then
      shown=0
    else
      shown=$(printf '%s\n' "$RANKED" | awk 'NF { count++ } END { print count+0 }')
    fi
    while IFS='|' read -r score age_days file; do
      [ -z "$file" ] && continue
      age_str=$(format_age "$age_days")
      snippet=$(extract_snippet "$file" "$QUERY" "$SNIPPET_CHARS" | sed -e 's/\\/\\\\/g' -e 's/"/\\"/g')
      printf '    {"rank": %d, "file": "%s", "age": "%s", "age_days": %d, "snippet": "%s"}' \
        "$rank" "$file" "$age_str" "$age_days" "$snippet"
      [ "$rank" -lt "$shown" ] && printf ',\n' || printf '\n'
      rank=$((rank + 1))
    done <<< "$RANKED"
    printf '  ],\n  "total": %d\n}\n' "$TOTAL_MATCHES"
    ;;
  simple)
    echo "$TOTAL_MATCHES"
    ;;
esac
