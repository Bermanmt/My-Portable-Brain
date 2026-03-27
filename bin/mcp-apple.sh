#!/bin/bash

# =============================================================================
# Portable Brain — Apple Native MCP Server (Shell Edition)
# =============================================================================
# Implements the MCP stdio transport protocol directly in bash.
# Uses osascript directly (not as a child process) so macOS TCC grants
# Calendar and Mail access to the shell process itself.
#
# Requires: bash, python3, osascript (all come with macOS)
# Usage: Claude Desktop will call this script and communicate via stdin/stdout
# =============================================================================

PY="python3"

# --- JSON helpers (via python3 which ships with macOS) ---
json_get() {
    echo "$1" | $PY -c "
import json,sys
try:
    d = json.load(sys.stdin)
    keys = '$2'.split('.')
    v = d
    for k in keys:
        if isinstance(v, dict): v = v.get(k)
        else: v = None
    if v is None: print('')
    else: print(v)
except: print('')
" 2>/dev/null
}

json_encode_str() {
    # Encodes a string for safe embedding in JSON
    echo "$1" | $PY -c "import json,sys; print(json.dumps(sys.stdin.read().rstrip('\n')))"
}

# --- JXA calendar script ---
get_calendar_events() {
    local days="${1:-3}"
    osascript -l JavaScript <<APPLESCRIPT
function run() {
  // Format date with local timezone offset instead of UTC (toISOString converts to UTC)
  function toLocalISO(d) {
    var off = -d.getTimezoneOffset();
    var sign = off >= 0 ? '+' : '-';
    var pad = function(n) { return String(Math.abs(n)).padStart(2, '0'); };
    return d.getFullYear() + '-' + pad(d.getMonth()+1) + '-' + pad(d.getDate()) +
      'T' + pad(d.getHours()) + ':' + pad(d.getMinutes()) + ':' + pad(d.getSeconds()) +
      sign + pad(Math.floor(Math.abs(off)/60)) + ':' + pad(Math.abs(off)%60);
  }

  var Calendar = Application("Calendar");
  var today = new Date();
  today.setHours(0, 0, 0, 0);
  var end = new Date(today);
  end.setDate(end.getDate() + $days);

  var calendars = Calendar.calendars();
  var results = [];

  calendars.forEach(function(cal) {
    try {
      var allEvents = cal.events();
      allEvents.forEach(function(e) {
        try {
          var start = e.startDate();
          if (start >= today && start < end) {
            results.push({
              calendar: cal.name(),
              title: e.summary() || "",
              start: toLocalISO(start),
              end: toLocalISO(e.endDate()),
              location: e.location() || ""
            });
          }
        } catch(err) {}
      });
    } catch(err) {}
  });

  results.sort(function(a, b) { return new Date(a.start) - new Date(b.start); });
  return JSON.stringify(results);
}
APPLESCRIPT
}

# --- JXA mail script ---
get_recent_emails() {
    local limit="${1:-10}"
    osascript -l JavaScript <<APPLESCRIPT
function run() {
  // Local ISO formatter (same as calendar script)
  function toLocalISO(d) {
    var off = -d.getTimezoneOffset();
    var sign = off >= 0 ? '+' : '-';
    var pad = function(n) { return String(Math.abs(n)).padStart(2, '0'); };
    return d.getFullYear() + '-' + pad(d.getMonth()+1) + '-' + pad(d.getDate()) +
      'T' + pad(d.getHours()) + ':' + pad(d.getMinutes()) + ':' + pad(d.getSeconds()) +
      sign + pad(Math.floor(Math.abs(off)/60)) + ':' + pad(Math.abs(off)%60);
  }

  var Mail = Application("Mail");
  var results = [];
  try {
    var accounts = Mail.accounts();
    accounts.forEach(function(account) {
      try {
        var mailboxes = account.mailboxes();
        mailboxes.forEach(function(mb) {
          try {
            var name = mb.name().toLowerCase();
            if (name === "inbox" || name === "bandeja de entrada") {
              var msgs = mb.messages();
              msgs.slice(0, $limit).forEach(function(m) {
                try {
                  results.push({
                    subject: m.subject() || "",
                    sender: m.sender() || "",
                    date: toLocalISO(m.dateSent()),
                    isRead: m.readStatus()
                  });
                } catch(err) {}
              });
            }
          } catch(err) {}
        });
      } catch(err) {}
    });
  } catch(e) {}
  results.sort(function(a,b){ return new Date(b.date) - new Date(a.date); });
  return JSON.stringify(results.slice(0, $limit));
}
APPLESCRIPT
}

# --- MCP Response builders ---
respond_initialize() {
    local id="$1"
    echo "{\"jsonrpc\":\"2.0\",\"id\":$id,\"result\":{\"protocolVersion\":\"2024-11-05\",\"capabilities\":{\"tools\":{}},\"serverInfo\":{\"name\":\"portable-brain-apple\",\"version\":\"1.0.0\"}}}"
}

respond_tools_list() {
    local id="$1"
    echo "{\"jsonrpc\":\"2.0\",\"id\":$id,\"result\":{\"tools\":[{\"name\":\"get_calendar_events\",\"description\":\"Fetch upcoming events from macOS Apple Calendar. Asks system for permission on first use.\",\"inputSchema\":{\"type\":\"object\",\"properties\":{\"days_ahead\":{\"type\":\"number\",\"description\":\"Number of days to look ahead (default: 3)\"}}}},{\"name\":\"get_recent_emails\",\"description\":\"Fetch recent emails from macOS Apple Mail inbox. Asks system for permission on first use.\",\"inputSchema\":{\"type\":\"object\",\"properties\":{\"limit\":{\"type\":\"number\",\"description\":\"Number of emails to retrieve (default: 10, max: 50)\"}}}}]}}"
}

respond_tool_result() {
    local id="$1"
    local text="$2"
    local encoded
    encoded=$(json_encode_str "$text")
    echo "{\"jsonrpc\":\"2.0\",\"id\":$id,\"result\":{\"content\":[{\"type\":\"text\",\"text\":$encoded}]}}"
}

respond_error() {
    local id="$1"
    local msg="$2"
    echo "{\"jsonrpc\":\"2.0\",\"id\":$id,\"error\":{\"code\":-32000,\"message\":\"$msg\"}}"
}

# --- Main loop ---
echo "Portable Brain Apple MCP (shell) running on stdio" >&2

while IFS= read -r line; do
    [ -z "$line" ] && continue

    method=$(json_get "$line" "method")
    id=$(json_get "$line" "id")
    [ -z "$id" ] && id="null"

    case "$method" in
        "initialize")
            respond_initialize "$id"
            ;;
        "notifications/initialized")
            # Notification — no response needed
            ;;
        "tools/list")
            respond_tools_list "$id"
            ;;
        "tools/call")
            tool=$(json_get "$line" "params.name")
            case "$tool" in
                "get_calendar_events")
                    days=$(json_get "$line" "params.arguments.days_ahead")
                    [ -z "$days" ] || [ "$days" = "None" ] && days=3
                    events=$(get_calendar_events "$days" 2>/dev/null)
                    [ -z "$events" ] && events="[]"
                    respond_tool_result "$id" "$events"
                    ;;
                "get_recent_emails")
                    limit=$(json_get "$line" "params.arguments.limit")
                    [ -z "$limit" ] || [ "$limit" = "None" ] && limit=10
                    [ "$limit" -gt 50 ] 2>/dev/null && limit=50
                    emails=$(get_recent_emails "$limit" 2>/dev/null)
                    [ -z "$emails" ] && emails="[]"
                    respond_tool_result "$id" "$emails"
                    ;;
                *)
                    respond_error "$id" "Unknown tool: $tool"
                    ;;
            esac
            ;;
        *)
            # Unknown method — respond with empty result to avoid blocking
            if [ "$id" != "null" ] && [ -n "$id" ]; then
                echo "{\"jsonrpc\":\"2.0\",\"id\":$id,\"result\":{}}"
            fi
            ;;
    esac
done
