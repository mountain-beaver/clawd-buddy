// Claude Code integration: hook payload normalisation and ~/.claude/settings.json install/uninstall.
const fs = require("fs");
const os = require("os");
const path = require("path");

const PORT = 47321;
const HOOK_URL = `http://127.0.0.1:${PORT}/hook`;
const SETTINGS = path.join(os.homedir(), ".claude", "settings.json");
const BACKUP = SETTINGS + ".bak-clawdbuddy";
const EVENTS = ["SessionStart", "UserPromptSubmit", "PreToolUse", "PostToolUseFailure", "Stop", "Notification"];
const TOOL_EVENTS = new Set(["PreToolUse", "PostToolUseFailure"]);

const truncate = (s, n) => (s.length > n ? s.slice(0, n - 1) + "…" : s);
const isOurs = (h) => h && h.type === "http" && typeof h.url === "string" && h.url.startsWith(HOOK_URL);
const hasOurs = (group) => (group.hooks || []).some(isOurs);

/** Boils a hook payload down to what the buddy needs. Mirrors macos/Sources/HookBridge.swift. */
function normalize(j) {
  const tool = j.tool_name || "";
  const input = j.tool_input || {};
  const str = (k) => (typeof input[k] === "string" ? input[k] : "");
  let detail;
  switch (tool) {
    case "Edit": case "MultiEdit": case "Write": case "Read":
      detail = path.win32.basename(str("file_path")); break;
    case "NotebookEdit":
      detail = path.win32.basename(str("notebook_path")); break;
    case "Bash": case "PowerShell":
      detail = truncate((str("command").split("\n")[0] || "").trim(), 34); break;
    case "Grep": case "Glob":
      detail = truncate(str("pattern"), 28); break;
    case "WebSearch":
      detail = truncate(str("query"), 30); break;
    case "WebFetch":
      try { detail = new URL(str("url")).host; } catch { detail = ""; } break;
    case "Agent": case "Task":
      detail = truncate(str("description"), 30); break;
    default:
      detail = tool.startsWith("mcp__") ? tool.split("__").pop() : tool;
  }
  return {
    event: j.hook_event_name || "", tool, detail,
    message: typeof j.message === "string" ? j.message : "",
    kind: typeof j.notification_type === "string" ? j.notification_type : "",
  };
}

/** Throws on invalid JSON so we never overwrite a file we couldn't parse. */
function read() {
  if (!fs.existsSync(SETTINGS)) return {};
  const text = fs.readFileSync(SETTINGS, "utf8");
  return text.trim() ? JSON.parse(text) : {};
}

function write(settings) {
  fs.mkdirSync(path.dirname(SETTINGS), { recursive: true });
  const tmp = SETTINGS + ".tmp-clawdbuddy";
  fs.writeFileSync(tmp, JSON.stringify(settings, null, 2) + "\n");
  fs.renameSync(tmp, SETTINGS);
}

/** Removes our entries, leaving everyone else's hooks alone. */
function strip(settings) {
  if (!settings.hooks) return;
  for (const event of Object.keys(settings.hooks)) {
    const groups = settings.hooks[event];
    if (!Array.isArray(groups)) continue;
    settings.hooks[event] = groups.flatMap((g) => {
      if (!hasOurs(g)) return [g];
      const rest = g.hooks.filter((h) => !isOurs(h));
      return rest.length ? [{ ...g, hooks: rest }] : [];
    });
    if (settings.hooks[event].length === 0) delete settings.hooks[event];
  }
  if (Object.keys(settings.hooks).length === 0) delete settings.hooks;
}

function status() {
  try {
    const s = read();
    const installed = EVENTS.every((e) => Array.isArray(s.hooks?.[e]) && s.hooks[e].some(hasOurs));
    return { installed, error: false, path: SETTINGS };
  } catch {
    return { installed: false, error: true, path: SETTINGS };
  }
}

function install() {
  const s = read();
  if (!fs.existsSync(BACKUP) && fs.existsSync(SETTINGS)) fs.copyFileSync(SETTINGS, BACKUP);
  strip(s);
  s.hooks = s.hooks || {};
  const ours = { type: "http", url: HOOK_URL, timeout: 2 };
  for (const e of EVENTS) {
    s.hooks[e] = s.hooks[e] || [];
    s.hooks[e].push(TOOL_EVENTS.has(e) ? { matcher: "*", hooks: [ours] } : { hooks: [ours] });
  }
  write(s);
}

function uninstall() {
  const s = read();
  strip(s);
  write(s);
}

module.exports = { PORT, normalize, status, install, uninstall };
