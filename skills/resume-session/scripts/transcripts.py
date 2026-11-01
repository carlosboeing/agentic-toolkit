"""Transcript readers for Claude Code, Codex, OpenCode, Antigravity CLI, Grok Build, and
Muse Code.

Each reader turns one harness's transcript into the same list of events and declares
which kinds of record its harness keeps. Formats are undocumented; they were probed on
Claude Code 2.1.316, Codex CLI 0.166.0, OpenCode 2.1.4, Antigravity CLI 1.4.12, Grok
Build 1.0.41, and Muse Code 1.4.14. Unknown record types are counted, not fatal. SQLite
stores are opened read-only.
"""

import json
import os
import re
import sqlite3
from contextlib import closing
from datetime import datetime, timedelta, timezone
from pathlib import Path
from urllib.parse import quote, unquote, urlparse

KINDS = ["user messages", "agent messages", "commands", "file edits", "file reads",
         "command results", "task list", "working directories", "timestamps"]

TEST_RUNNER = re.compile(
    r"^(?:uv run(?:\s+-\S+(?:\s+[\d.]+)?)*\s+)?"
    r"(?:python3?(?:\.\d+)? -m (?:unittest|pytest)|pytest|tox|"
    r"(?:npm|pnpm|yarn|bun)(?: run)? test|go test|cargo test|make (?:test|check)|npx (?:vitest|jest)|vitest|jest|rspec|"
    r"mvn test|gradle test|(?:ba|z)?sh \S*(?:test[-_][\w-]*|run-tests)\.sh|\S*/(?:test[-_][\w-]*|run-tests)\.sh)\b")
SEGMENT_PREFIX = re.compile(r"^(?:(?:rtk(?:\s+proxy)?|time|env|command)\s+|\w+=\S*\s+|cd\s+\S+\s*$)+")
# A zero count ("0 failed", "failures=0") is not a failure.
FAIL_WORDS = re.compile(r"\bFAILED\b|\bFAIL\b|\b[1-9]\d* failed\b|\bfailures?=[1-9]|\bTraceback\b|\berrors?=[1-9]")
PASS_WORDS = re.compile(r"\bOK\b|\bPASS(?:ED)?\b|\b\d+ passed\b|\ball tests passed\b", re.I)
VERDICT_LINE = re.compile(r"(passed|failed|\bOK\b|FAILED|PASS|FAIL|\btests? ran\b|^Ran \d+)", re.I)
DOC_PATH = re.compile(r"(?<![\w/.~-])((?:~|\.{1,2})?/?[\w.~-]+(?:/[\w.~-]+)*\.(?:md|mdx|markdown|rst|adoc|txt))\b")
READ_COMMAND = re.compile(r"^(?:rtk\s+(?:proxy\s+)?)?(?:cat|sed|head|tail|nl|less|bat|rg|grep)\b")


class Event:
    __slots__ = ("kind", "time", "text", "path", "cwd", "ref", "error", "verdict")

    def __init__(self, kind, time, text="", path=None, cwd=None, ref=None, error=False, verdict=None):
        self.kind, self.time, self.text, self.path = kind, time, text, path
        self.cwd, self.ref, self.error, self.verdict = cwd, ref, error, verdict


class Transcript:
    def __init__(self, harness, path):
        self.harness = harness
        self.path = Path(path)
        self.session_id = None
        self.title = None
        self.model = None
        self.effort = None
        self.version = None
        self.cwds = []
        self.events = []
        self.tasks = None
        self.bad_lines = 0
        self.unknown = {}
        self.compactions = 0
        self.subagent = False
        self.declared = {}
        self.raw_hex = set()

    def add_cwd(self, cwd):
        if cwd and cwd not in self.cwds:
            self.cwds.append(cwd)

    def of(self, kind):
        return [e for e in self.events if e.kind == kind]

    @property
    def started(self):
        times = [e.time for e in self.events if e.time]
        return min(times) if times else None

    @property
    def last_activity(self):
        times = [e.time for e in self.events if e.time]
        return max(times) if times else None


def parse_time(value):
    if not value or not isinstance(value, str):
        return None
    try:
        return datetime.fromisoformat(value.replace("Z", "+00:00")[:32])
    except ValueError:
        match = re.match(r"(\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2})(?:\.\d+)?(Z|[+-]\d{2}:\d{2})?", value)
        if not match:
            return None
        zone = match.group(2) or "+00:00"
        return datetime.fromisoformat(match.group(1) + ("+00:00" if zone == "Z" else zone))


def is_test_command(command):
    """True when a command segment starts with a test runner; a command that only names a
    test file, such as `cat tests/test-x.sh`, is not a run."""
    for segment in re.split(r"&&|\|\||[;|\n]", command):
        segment = SEGMENT_PREFIX.sub("", segment.strip())
        if TEST_RUNNER.search(segment):
            return True
    return False


def verdict_of(text, error=None, exit_code=None):
    """pass, fail, or unknown: a keyword match on the result, labeled as such."""
    if FAIL_WORDS.search(text or ""):
        return "fail"
    if error or (exit_code is not None and exit_code != 0):
        return "fail"
    if PASS_WORDS.search(text or "") or exit_code == 0 or error is False:
        return "pass"
    return "unknown"


def verdict_line(text):
    lines = [line.strip() for line in (text or "").splitlines() if VERDICT_LINE.search(line)]
    return lines[-1][:160] if lines else ""


HEX = re.compile(r"\b[0-9a-f]{7,40}\b")


def remember_hex(transcript, line):
    for token in HEX.findall(line):
        if not token.isdigit():
            transcript.raw_hex.add(token[:7])


# ---------------------------------------------------------------- Claude Code

CLAUDE_KNOWN = {"user", "assistant", "system", "attachment", "ai-title", "summary", "last-prompt", "mode",
                "permission-mode", "file-history-snapshot", "file-history-delta", "api-request",
                "api-request-shape", "api-request-blob", "atis-latch", "tools-used", "queue-operation",
                "pr-link", "custom-title", "tag"}
COMMAND_NAME = re.compile(r"<command-name>(.*?)</command-name>", re.S)
COMMAND_ARGS = re.compile(r"<command-args>(.*?)</command-args>", re.S)


def claude_home():
    return Path(os.environ.get("CLAUDE_CONFIG_DIR") or Path.home() / ".claude")


def claude_project_dir(cwd):
    return claude_home() / "projects" / re.sub(r"[^A-Za-z0-9]", "-", str(cwd))


def read_claude(path):
    t = Transcript("claude", path)
    t.session_id = Path(path).stem
    t.declared = {kind: "recorded" for kind in KINDS}
    pending = {}
    last_agent_id = None
    with open(path, errors="replace") as handle:
        for line in handle:
            remember_hex(t, line)
            try:
                r = json.loads(line)
            except ValueError:
                t.bad_lines += 1
                continue
            if not isinstance(r, dict):
                t.bad_lines += 1
                continue
            kind = r.get("type")
            if kind not in CLAUDE_KNOWN:
                t.unknown[kind] = t.unknown.get(kind, 0) + 1
                continue
            if kind == "ai-title" and r.get("aiTitle"):
                t.title = r["aiTitle"]
            if kind not in ("user", "assistant") or r.get("isSidechain"):
                continue
            t.version = r.get("version") or t.version
            when = parse_time(r.get("timestamp"))
            cwd = r.get("cwd")
            t.add_cwd(cwd)
            message = r.get("message") or {}
            content = message.get("content")
            if kind == "user":
                if isinstance(content, list) and any(isinstance(p, dict) and p.get("type") == "tool_result" for p in content):
                    for part in content:
                        if isinstance(part, dict) and part.get("type") == "tool_result":
                            ref = part.get("tool_use_id")
                            text = _claude_result_text(part.get("content"))
                            source = pending.get(ref)
                            if source is not None and source.kind == "command" and is_test_command(source.text):
                                error = bool(part.get("is_error"))
                                source.verdict = (verdict_of(text, error=error), verdict_line(text))
                    continue
                if r.get("isMeta") or r.get("isCompactSummary"):
                    if r.get("isCompactSummary"):
                        t.compactions += 1
                    continue
                text = content if isinstance(content, str) else " ".join(
                    p.get("text", "") for p in content or [] if isinstance(p, dict) and p.get("type") == "text")
                text = _claude_user_text(text)
                previous = next((e for e in reversed(t.events) if e.kind == "user"), None)
                if text and not (previous and previous.text == text and t.events[-1] is previous):
                    t.events.append(Event("user", when, text, cwd=cwd))
                last_agent_id = None
                continue
            t.model = message.get("model") or t.model
            t.effort = r.get("effort") or t.effort
            for part in content if isinstance(content, list) else []:
                if not isinstance(part, dict):
                    continue
                if part.get("type") == "text" and part.get("text", "").strip():
                    if last_agent_id and last_agent_id == message.get("id") and t.events and t.events[-1].kind == "agent":
                        t.events[-1].text += "\n\n" + part["text"]
                    else:
                        t.events.append(Event("agent", when, part["text"], cwd=cwd))
                    last_agent_id = message.get("id")
                elif part.get("type") == "tool_use":
                    for event in _claude_tool(part, when, cwd, t):
                        t.events.append(event)
                        pending[part.get("id")] = event
    return t


def _claude_result_text(content):
    if isinstance(content, str):
        return content
    if isinstance(content, list):
        return "\n".join(p.get("text", "") for p in content if isinstance(p, dict))
    return ""


def _claude_user_text(text):
    text = text.strip()
    if text.startswith("<local-command-stdout>") or text.startswith("<local-command-caveat>"):
        return ""
    name = COMMAND_NAME.search(text)
    if name:
        args = COMMAND_ARGS.search(text)
        return (name.group(1).strip() + " " + (args.group(1).strip() if args else "")).strip()
    return text


def _claude_tool(part, when, cwd, t):
    name = part.get("name") or ""
    data = part.get("input") or {}
    if name == "Bash" and data.get("command"):
        yield Event("command", when, data["command"], cwd=cwd, ref=part.get("id"))
    elif name in ("Edit", "Write", "MultiEdit", "NotebookEdit"):
        path = data.get("file_path") or data.get("notebook_path")
        if path:
            yield Event("edit", when, name, path=path, cwd=cwd)
    elif name == "Read" and data.get("file_path"):
        yield Event("read", when, name, path=data["file_path"], cwd=cwd)
    elif name == "TodoWrite" and isinstance(data.get("todos"), list):
        t.tasks = [(item.get("status", ""), item.get("content", "")) for item in data["todos"] if isinstance(item, dict)]
    elif name in ("TaskCreate", "TaskUpdate"):
        tasks = dict((subject, status) for status, subject in (t.tasks or []))
        subject = data.get("subject") or data.get("taskId") or data.get("id")
        if subject:
            tasks[str(subject)] = data.get("status") or tasks.get(str(subject), "pending")
            t.tasks = [(status, subject) for subject, status in tasks.items()]


# ---------------------------------------------------------------- Codex

CODEX_KNOWN = {"session_meta", "turn_context", "response_item", "event_msg", "compacted",
               "token_usage_record", "world_state", "inter_agent_communication_metadata"}
CODEX_WRAPPERS = ("<environment_context>", "# AGENTS.md instructions", "<user_instructions>",
                  "<turn_aborted>", "<user_shell_command>", "<permissions instructions>")
JS_STRING = r'"((?:[^"\\]|\\.)*)"|\'((?:[^\'\\]|\\.)*)\'|`((?:[^`\\]|\\.)*)`'
JS_KEY = r'(?:"{key}"|\b{key})\s*:\s*(?:' + JS_STRING + ')'
PATCH_FILE = re.compile(r"^\*\*\* (?:Add|Update|Delete) File: (.+)$|^\*\*\* Move to: (.+)$", re.M)
EXIT_CODE = re.compile(r'exit_code\\?"?\s*[:=]\s*(-?\d+)')


def codex_home():
    return Path(os.environ.get("CODEX_HOME") or Path.home() / ".codex")


def _js_value(match):
    raw = next(g for g in match.groups() if g is not None)
    try:
        return json.loads('"' + raw.replace('\\\'', "'").replace("\n", "\\n") + '"')
    except ValueError:
        return raw


def _js_field(text, key):
    return [_js_value(m) for m in re.finditer(JS_KEY.format(key=key), text)]


def read_codex(path):
    t = Transcript("codex", path)
    match = re.search(r"([0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12})", Path(path).name)
    t.session_id = match.group(1) if match else Path(path).stem
    t.declared = {kind: "recorded" for kind in KINDS}
    t.declared["file reads"] = "partial: paths in read commands such as cat, sed, head, and rg"
    t.declared["task list"] = "recorded when the agent used update_plan"
    pending = {}
    cwd = None
    with open(path, errors="replace") as handle:
        for line in handle:
            remember_hex(t, line)
            try:
                r = json.loads(line)
            except ValueError:
                t.bad_lines += 1
                continue
            if not isinstance(r, dict):
                t.bad_lines += 1
                continue
            kind = r.get("type")
            payload = r.get("payload") if isinstance(r.get("payload"), dict) else {}
            when = parse_time(r.get("timestamp"))
            if kind not in CODEX_KNOWN:
                t.unknown[kind] = t.unknown.get(kind, 0) + 1
                continue
            if kind == "session_meta":
                t.session_id = payload.get("id") or t.session_id
                t.version = payload.get("cli_version")
                t.subagent = bool(payload.get("parent_thread_id") or payload.get("agent_path"))
                cwd = payload.get("cwd") or cwd
                t.add_cwd(cwd)
            elif kind == "turn_context":
                cwd = payload.get("cwd") or cwd
                t.add_cwd(cwd)
                t.model = payload.get("model") or t.model
                t.effort = payload.get("effort") or t.effort
            elif kind == "compacted":
                t.compactions += 1
            elif kind == "response_item":
                _codex_item(t, payload, when, cwd, pending)
    return t


def _codex_item(t, p, when, cwd, pending):
    kind = p.get("type")
    if kind == "message":
        parts = p.get("content") or []
        text = "".join(x.get("text", "") for x in parts if isinstance(x, dict) and x.get("type") in ("input_text", "output_text", "text"))
        if p.get("role") == "user":
            text = re.sub(r"<image[^>]*>.*?</image>", "", text, flags=re.S).strip()
            if text and not text.startswith(CODEX_WRAPPERS):
                t.events.append(Event("user", when, text, cwd=cwd))
        elif p.get("role") == "assistant" and text.strip():
            t.events.append(Event("agent", when, text, cwd=cwd))
    elif kind in ("custom_tool_call", "function_call"):
        body = p.get("input") if kind == "custom_tool_call" else p.get("arguments")
        body = body if isinstance(body, str) else json.dumps(body or {})
        events = list(_codex_tool(p.get("name") or "", body, when, cwd, t))
        t.events.extend(events)
        commands = [e for e in events if e.kind == "command"]
        if commands:
            pending[p.get("call_id")] = commands
    elif kind in ("custom_tool_call_output", "function_call_output"):
        commands = pending.pop(p.get("call_id"), None)
        if not commands:
            return
        codes, plain = _codex_output(p.get("output"))
        for index, command in enumerate(commands):
            if is_test_command(command.text):
                code = codes[index] if index < len(codes) else None
                text = plain if len(commands) == 1 else ""
                command.verdict = (verdict_of(text, exit_code=code), verdict_line(text))


def _codex_output(output):
    """Exit codes and plain text from a tool result. A result is a string or a list of
    text parts; a part can itself be a JSON object with `exit_code` and `output`."""
    parts = output if isinstance(output, list) else [{"text": output if isinstance(output, str) else json.dumps(output)}]
    codes, texts = [], []
    for part in parts:
        text = part.get("text", "") if isinstance(part, dict) else str(part)
        try:
            data = json.loads(text)
        except ValueError:
            data = None
        if isinstance(data, dict) and ("exit_code" in data or "output" in data):
            if isinstance(data.get("exit_code"), int):
                codes.append(data["exit_code"])
            texts.append(str(data.get("output", "")))
        else:
            codes.extend(int(c) for c in EXIT_CODE.findall(text))
            texts.append(text)
    return codes, "\n".join(texts)


def _codex_tool(name, body, when, cwd, t):
    if name in ("exec_command", "shell", "local_shell") or (name == "exec" and "tools." not in body):
        try:
            data = json.loads(body)
        except ValueError:
            data = {}
        command = data.get("cmd") or data.get("command")
        if isinstance(command, list):
            command = " ".join(command)
        if command:
            yield from _codex_command(command, data.get("workdir") or cwd, when)
        return
    if name == "apply_patch":
        for path in _patch_paths(body):
            yield Event("edit", when, "apply_patch", path=_absolute(path, cwd), cwd=cwd)
        return
    if name == "update_plan":
        try:
            plan = json.loads(body).get("plan") or []
        except ValueError:
            plan = []
        t.tasks = [(item.get("status", ""), item.get("step", "")) for item in plan if isinstance(item, dict)]
        return
    if name != "exec":
        return
    for segment in re.split(r"(?=tools\.\w+\()", body):
        tool = re.match(r"tools\.(\w+)\(", segment)
        if not tool:
            continue
        if tool.group(1) == "exec_command":
            commands = _js_field(segment, "cmd")
            workdirs = _js_field(segment, "workdir")
            if commands:
                yield from _codex_command(commands[0], workdirs[0] if workdirs else cwd, when)
        elif tool.group(1) == "apply_patch":
            strings = [_js_value(m) for m in re.finditer(JS_STRING, segment)]
            for path in _patch_paths("\n".join(strings)):
                yield Event("edit", when, "apply_patch", path=_absolute(path, cwd), cwd=cwd)
        elif tool.group(1) == "update_plan":
            steps = _js_field(segment, "step")
            statuses = _js_field(segment, "status")
            t.tasks = list(zip(statuses + [""] * len(steps), steps))


def _codex_command(command, workdir, when):
    """A command event, plus a read event for each document a read command names."""
    yield Event("command", when, command, cwd=workdir)
    if READ_COMMAND.search(command.strip()):
        for match in DOC_PATH.finditer(command):
            yield Event("read", when, "read command", path=_absolute(match.group(1), workdir), cwd=workdir)


def _patch_paths(text):
    return [m.group(1) or m.group(2) for m in PATCH_FILE.finditer(text)]


# ---------------------------------------------------------------- shared by the newer readers

# Per harness: command tools and their command key, then read, edit, and task-list tools
# with the argument keys that carry the path or the item text.
TOOL_MAPS = {
    "opencode": {"command": {"shell": "command", "bash": "command"},
                 "read": {"read": ("filePath", "path")},
                 "edit": {name: ("filePath", "path") for name in ("edit", "write", "patch", "multiedit")},
                 "todo": {"todowrite": ("todos", "content")}},
    "antigravity": {"command": {"run_command": "CommandLine"},
                    "read": {"view_file": ("AbsolutePath",), "read_file": ("Path",)},
                    "edit": {"write_to_file": ("TargetFile",), "replace_file_content": ("TargetFile",),
                             "multi_replace_file_content": ("TargetFile",), "edit_file": ("Path",),
                             "write_file": ("Path",)},
                    "todo": {}},
    "grok": {"command": {"run_terminal_command": "command"},
             "read": {"read_file": ("target_file",)},
             "edit": {"search_replace": ("file_path",), "write": ("file_path",)},
             "todo": {"todo_write": ("todos", "content")}},
    "muse": {"command": {"bash": "command"},
             "read": {"read_file": ("path",)},
             "edit": {"edit_file": ("path",), "write_file": ("path",)},
             "todo": {"write_todos": ("todos", "text")}},
}
USER_QUERY = re.compile(r"<user_query>(.*?)</user_query>", re.S)
USER_REQUEST = re.compile(r"<USER_REQUEST>(.*?)</USER_REQUEST>", re.S)
EXIT_LINE = re.compile(r"(?:Command exited with code|exit code:?)\s*(-?\d+)", re.I)


def data_home():
    return Path(os.environ.get("XDG_DATA_HOME") or Path.home() / ".local" / "share")


def opencode_db():
    return data_home() / "opencode" / "opencode.db"


def muse_home():
    return data_home() / "muse"


def grok_home():
    return Path(os.environ.get("GROK_HOME") or Path.home() / ".grok")


def antigravity_home():
    return Path.home() / ".gemini" / "antigravity-cli"


def connect(path):
    """A read-only connection; it never creates the file and never writes."""
    return closing(sqlite3.connect(f"file:{quote(str(path))}?mode=ro", uri=True, timeout=2))


def ms_time(value):
    return datetime.fromtimestamp(value / 1000, timezone.utc) if isinstance(value, (int, float)) else None


def us_time(value):
    return datetime.fromtimestamp(value / 1_000_000, timezone.utc) if isinstance(value, (int, float)) else None


def _loads(text):
    try:
        value = json.loads(text) if isinstance(text, str) else text
    except ValueError:
        return None
    return value if isinstance(value, dict) else None


def _tool(t, name, data, when, cwd):
    """Events for one tool call from the harness's tool map. Returns the command event, so
    its result can set a test verdict."""
    tools = TOOL_MAPS[t.harness]
    data = data if isinstance(data, dict) else {}
    if name in tools["command"]:
        command = data.get(tools["command"][name])
        if isinstance(command, str) and command.strip():
            events = list(_codex_command(command, data.get("workdir") or data.get("cwd") or cwd, when))
            t.events.extend(events)
            return events[0]
        return None
    for kind in ("read", "edit"):
        if name in tools[kind]:
            path = next((data[k] for k in tools[kind][name] if isinstance(data.get(k), str)), None)
            if path:
                t.events.append(Event(kind, when, name, path=_absolute(path, cwd), cwd=cwd))
            return None
    if name in tools["todo"]:
        key, text_key = tools["todo"][name]
        items = data.get(key)
        if isinstance(items, list):
            t.tasks = [(item.get("status", ""), item.get(text_key) or item.get("content") or "")
                       for item in items if isinstance(item, dict)]
    return None


def _result(command, text, exit_code=None):
    if command is not None and is_test_command(command.text):
        if exit_code is None:
            match = EXIT_LINE.search(text or "")
            exit_code = int(match.group(1)) if match else None
        command.verdict = (verdict_of(text, exit_code=exit_code), verdict_line(text))


def _agent(t, when, text, cwd, merge_key=None):
    """An agent message; text parts of one message join into one event."""
    if not (text or "").strip():
        return
    last = t.events[-1] if t.events else None
    if merge_key is not None and last is not None and last.kind == "agent" and last.ref == merge_key:
        last.text += "\n\n" + text
    else:
        t.events.append(Event("agent", when, text, cwd=cwd, ref=merge_key))


def grok_user_text(record):
    """The typed request from a Grok user record, without the context it wraps it in."""
    if record.get("type") != "user" or record.get("prompt_index") is None or record.get("synthetic_reason"):
        return ""
    content = record.get("content")
    text = content if isinstance(content, str) else "\n".join(
        p.get("text", "") for p in content or [] if isinstance(p, dict))
    match = USER_QUERY.search(text)
    return (match.group(1) if match else text).strip()


def antigravity_user_text(record):
    if record.get("type") != "USER_INPUT":
        return ""
    text = record.get("content") or ""
    match = USER_REQUEST.search(text)
    return (match.group(1) if match else text).strip()


def muse_user_text(record):
    if record.get("payload_type") != "runtime.user_intent.accepted":
        return ""
    payload = record.get("payload") or {}
    return "\n".join(b.get("text", "") for b in payload.get("refill_blocks") or []
                     if isinstance(b, dict) and b.get("kind") == "text").strip()


# ---------------------------------------------------------------- OpenCode

OPENCODE_SKIP = {"synthetic", "system", "idle", "shell", "agent-switched", "location-switched", "compaction"}


def opencode_path(session_id):
    """OpenCode keeps every session in one database; a session is named `<db>#<id>`."""
    return Path(f"{opencode_db()}#{session_id}")


def _tables(db):
    return {row[0] for row in db.execute("select name from sqlite_master where type='table'")}


def _opencode_session(db, session_id):
    tables = _tables(db)
    for schema, table in ((2, "session_v2"), (1, "session")):
        if table in tables:
            row = db.execute(f"select directory, title, version from {table} where id = ?", (session_id,)).fetchone()
            if row:
                return (schema, *row)
    return None


def read_opencode(path):
    db_path, _, session_id = str(path).partition("#")
    t = Transcript("opencode", path)
    t.session_id = session_id
    t.declared = {kind: "recorded" for kind in KINDS}
    t.declared["task list"] = "recorded when the agent used todowrite"
    with connect(db_path) as db:
        found = _opencode_session(db, session_id)
        if found is None:
            raise ValueError(f"no OpenCode session {session_id} in {db_path}")
        schema, cwd, t.title, t.version = found
        t.add_cwd(cwd)
        if schema == 2:
            _opencode_v2(t, db, cwd)
        else:
            _opencode_v1(t, db, cwd)
    return t


def _opencode_v2(t, db, cwd):
    rows = db.execute("select id, type, data from session_message where session_id = ? order by seq", (t.session_id,))
    for row_id, kind, raw in rows:
        data = _loads(raw)
        if data is None:
            t.bad_lines += 1
            continue
        when = ms_time((data.get("time") or {}).get("created"))
        if kind == "user":
            text = (data.get("text") or "").strip()
            if text:
                t.events.append(Event("user", when, text, cwd=cwd))
        elif kind == "assistant":
            t.model = (data.get("model") or {}).get("id") or t.model
            _opencode_parts(t, data.get("content") or [], when, cwd, row_id)
        elif kind not in OPENCODE_SKIP:
            t.unknown[kind] = t.unknown.get(kind, 0) + 1


def _opencode_v1(t, db, cwd):
    parts = {}
    for message_id, raw in db.execute("select message_id, data from part where session_id = ? order by time_created, id",
                                      (t.session_id,)):
        parts.setdefault(message_id, []).append(_loads(raw) or {})
    for message_id, raw in db.execute("select id, data from message where session_id = ? order by time_created, id",
                                      (t.session_id,)):
        data = _loads(raw)
        if data is None:
            t.bad_lines += 1
            continue
        when = ms_time((data.get("time") or {}).get("created"))
        mine = parts.get(message_id, [])
        if data.get("role") == "user":
            text = "\n".join(p.get("text", "") for p in mine if p.get("type") == "text" and not p.get("synthetic")).strip()
            if text:
                t.events.append(Event("user", when, text, cwd=cwd))
        else:
            t.model = data.get("modelID") or t.model
            t.compactions += sum(1 for p in mine if p.get("type") == "compaction")
            _opencode_parts(t, mine, when, cwd, message_id)


def _opencode_parts(t, parts, when, cwd, message_id):
    for part in parts:
        if not isinstance(part, dict):
            continue
        if part.get("type") == "text" and not part.get("synthetic"):
            _agent(t, when, part.get("text", ""), cwd, message_id)
        elif part.get("type") == "tool":
            state = part.get("state") or {}
            command = _tool(t, part.get("name") or part.get("tool") or "", state.get("input"), when, cwd)
            output = state.get("output")
            if not isinstance(output, str):
                output = "\n".join(c.get("text", "") for c in state.get("content") or [] if isinstance(c, dict))
            exit_code = (state.get("metadata") or {}).get("exit")
            _result(command, output, exit_code if isinstance(exit_code, int) else None)


# ---------------------------------------------------------------- Antigravity CLI

ANTIGRAVITY_KNOWN = {"USER_INPUT", "PLANNER_RESPONSE", "GENERIC", "SYSTEM_MESSAGE", "CHECKPOINT"}
TASK_LINE = re.compile(r"^\s*[-*]\s+\[([ xX/])\]\s+(.*)$")


def antigravity_transcript(conversation_id):
    return (antigravity_home() / "brain" / conversation_id / ".system_generated" / "logs"
            / "transcript_full.jsonl")


def antigravity_summary(conversation_id):
    database = antigravity_home() / "conversation_summaries.db"
    if not database.is_file():
        return None
    try:
        with connect(database) as db:
            return db.execute("select title, preview, workspace_uris from conversation_summaries "
                              "where conversation_id = ?", (conversation_id,)).fetchone()
    except sqlite3.Error:
        return None


def _workspace_paths(uris):
    try:
        values = json.loads(uris or "[]")
    except ValueError:
        return []
    return [unquote(urlparse(u).path) for u in values if isinstance(u, str) and u.startswith("file://")]


def read_antigravity(path):
    t = Transcript("antigravity", path)
    t.session_id = Path(path).parents[2].name
    t.declared = {kind: "recorded" for kind in KINDS}
    t.declared["file reads"] = "recorded for view_file and read_file"
    t.declared["task list"] = "recorded from the conversation's task.md or tasks.md artifact"
    summary = antigravity_summary(t.session_id)
    if summary:
        t.title = summary[0] or summary[1] or None
        for workspace in _workspace_paths(summary[2]):
            t.add_cwd(workspace)
    cwd = t.cwds[0] if t.cwds else None
    pending = []
    with open(path, errors="replace") as handle:
        for line in handle:
            remember_hex(t, line)
            r = _loads(line)
            if r is None:
                t.bad_lines += 1
                continue
            kind = r.get("type")
            when = parse_time(r.get("created_at"))
            if kind not in ANTIGRAVITY_KNOWN:
                t.unknown[kind] = t.unknown.get(kind, 0) + 1
            elif kind == "USER_INPUT":
                text = antigravity_user_text(r)
                if text:
                    t.events.append(Event("user", when, text, cwd=cwd))
            elif kind == "PLANNER_RESPONSE":
                _agent(t, when, r.get("content") or "", cwd)
                pending = [_tool(t, c.get("name") or "", c.get("args"), when, cwd)
                           for c in r.get("tool_calls") or [] if isinstance(c, dict)]
            elif kind == "GENERIC" and pending:
                _result(pending.pop(0), r.get("content") or "")
            elif kind == "CHECKPOINT":
                t.compactions += 1
    task_file = next((f for f in (Path(path).parents[2] / n for n in ("task.md", "tasks.md")) if f.is_file()), None)
    if task_file:
        tasks = [m.groups() for m in map(TASK_LINE.match, task_file.read_text(errors="replace").splitlines()) if m]
        t.tasks = [({"x": "completed", "X": "completed", "/": "in_progress"}.get(mark, "pending"), text.strip())
                   for mark, text in tasks] or None
    return t


# ---------------------------------------------------------------- Grok Build

GROK_KNOWN = {"system", "user", "assistant", "reasoning", "tool_result"}


def grok_folder(cwd):
    return grok_home() / "sessions" / quote(str(cwd), safe="")


def read_grok(path):
    folder = Path(path).parent
    t = Transcript("grok", path)
    t.session_id = folder.name
    t.declared = {kind: "recorded" for kind in KINDS}
    t.declared["timestamps"] = "partial: request and tool times from events.jsonl; agent messages take the last known time"
    summary = _loads((folder / "summary.json").read_text(errors="replace")) if (folder / "summary.json").is_file() else None
    summary = summary or {}
    t.title = summary.get("generated_title") or summary.get("session_summary") or None
    t.model = summary.get("current_model_id")
    t.effort = summary.get("reasoning_effort")
    cwd = (summary.get("info") or {}).get("cwd")
    t.add_cwd(cwd)
    turns, tool_times = _grok_times(folder / "events.jsonl")
    pending = {}
    when = turns[0] if turns else None
    with open(path, errors="replace") as handle:
        for line in handle:
            remember_hex(t, line)
            r = _loads(line)
            if r is None:
                t.bad_lines += 1
                continue
            kind = r.get("type")
            if kind not in GROK_KNOWN:
                t.unknown[kind] = t.unknown.get(kind, 0) + 1
            elif kind == "user":
                text = grok_user_text(r)
                if text:
                    index = r.get("prompt_index")
                    when = turns[index] if isinstance(index, int) and index < len(turns) else when
                    t.events.append(Event("user", when, text, cwd=cwd))
            elif kind == "assistant":
                t.model = r.get("model_id") or t.model
                content = r.get("content")
                _agent(t, when, content if isinstance(content, str) else "", cwd)
                for call in r.get("tool_calls") or []:
                    if not isinstance(call, dict):
                        continue
                    when = tool_times.get(call.get("id"), when)
                    command = _tool(t, call.get("name") or "", _loads(call.get("arguments")), when, cwd)
                    if command is not None:
                        pending[call.get("id")] = command
            elif kind == "tool_result":
                content = r.get("content")
                _result(pending.pop(r.get("tool_call_id"), None), content if isinstance(content, str) else json.dumps(content))
    return t


def _grok_times(path):
    """Turn start times in order, and each tool call's completion time."""
    turns, tools = [], {}
    try:
        with open(path, errors="replace") as handle:
            for line in handle:
                r = _loads(line) or {}
                if r.get("type") == "turn_started":
                    turns.append(parse_time(r.get("ts")))
                elif r.get("type") == "tool_completed" and r.get("tool_call_id"):
                    tools[r["tool_call_id"]] = parse_time(r.get("ts"))
    except OSError:
        pass
    return turns, tools


# ---------------------------------------------------------------- Muse Code

def muse_title(session_id):
    database = muse_home() / "session-index.db"
    if not database.is_file():
        return None
    try:
        with connect(database) as db:
            row = db.execute("select effective_long_title, title from sessions where session_id = ?",
                             (session_id,)).fetchone()
    except sqlite3.Error:
        return None
    return (row[0] or row[1] or None) if row else None


def read_muse(path):
    t = Transcript("muse", path)
    t.session_id = Path(path).parent.name
    t.title = muse_title(t.session_id)
    t.declared = {kind: "recorded" for kind in KINDS}
    t.declared["task list"] = "recorded when the agent used write_todos"
    cwd = None
    pending = {}
    with open(path, errors="replace") as handle:
        for line in handle:
            remember_hex(t, line)
            r = _loads(line)
            if r is None:
                t.bad_lines += 1
                continue
            kind = r.get("payload_type")
            payload = r.get("payload") if isinstance(r.get("payload"), dict) else {}
            when = us_time(r.get("recorded_at"))
            if kind == "runtime.session.metadata":
                record = payload.get("record") or {}
                cwd = record.get("workspace_root") or cwd
                t.add_cwd(cwd)
                t.model = record.get("model_id") or t.model
                t.version = (record.get("build") or {}).get("semver") or t.version
            elif kind == "runtime.user_intent.accepted":
                text = muse_user_text(r)
                if text:
                    t.events.append(Event("user", when, text, cwd=cwd))
            elif kind == "runtime.session" and payload.get("kind") == "run":
                _muse_run(t, payload.get("event") or {}, when, cwd, pending)
    return t


def _muse_run(t, event, when, cwd, pending):
    kind = event.get("kind")
    if kind == "assistant_message_committed":
        _agent(t, when, event.get("text") or "", cwd)
    elif kind == "assistant_tool_calls_committed":
        for call in event.get("tool_calls") or []:
            if isinstance(call, dict):
                command = _tool(t, call.get("name") or "", _loads(call.get("args")), when, cwd)
                if command is not None:
                    pending[call.get("call_id")] = command
    elif kind == "tool_result_batch_committed":
        for result in event.get("results") or []:
            if not isinstance(result, dict):
                continue
            text = result.get("text") or ""
            data = _loads(text) or {}
            code = data.get("exit_code")
            _result(pending.pop(result.get("tool_call_id"), None), str(data.get("output", text)),
                    code if isinstance(code, int) else None)
    elif kind == "todo_snapshot_updated":
        t.tasks = [(i.get("status", ""), i.get("text", "")) for i in event.get("items") or [] if isinstance(i, dict)]


def _absolute(path, cwd):
    path = os.path.expanduser(path.strip())
    if os.path.isabs(path) or not cwd:
        return path
    return os.path.normpath(os.path.join(cwd, path))


# ---------------------------------------------------------------- finding sessions

HARNESSES = ("claude", "codex", "opencode", "antigravity", "grok", "muse")
SAFE_REF = re.compile(r"^[A-Za-z0-9_-]+$")


class Candidate:
    def __init__(self, harness, path, session_id, cwd, last, title, subagent=False,
                 first_request=None, last_request=None):
        self.harness, self.path, self.session_id = harness, Path(path), session_id
        self.cwd, self.last, self.title, self.subagent = cwd, last, title, subagent
        self.first_request, self.last_request = first_request, last_request


def _tail_records(path, size=262144):
    try:
        with open(path, "rb") as handle:
            handle.seek(0, os.SEEK_END)
            end = handle.tell()
            handle.seek(max(0, end - size))
            data = handle.read().decode("utf-8", errors="replace")
    except OSError:
        return []
    return _parse_lines(data.splitlines()[1 if end > size else 0:])


def _head_records(path, size=524288):
    try:
        with open(path, "rb") as handle:
            data = handle.read(size)
            more = bool(handle.read(1))
    except OSError:
        return []
    lines = data.decode("utf-8", errors="replace").splitlines()
    return _parse_lines(lines[:-1] if more else lines)


def _parse_lines(lines):
    records = []
    for line in lines:
        try:
            record = json.loads(line)
        except ValueError:
            continue
        if isinstance(record, dict):
            records.append(record)
    return records


def _first_record(path):
    try:
        with open(path, errors="replace") as handle:
            return json.loads(handle.readline())
    except (OSError, ValueError):
        return {}


def _ends(path, extract):
    """The first and the last request in a JSONL transcript, read from its two ends."""
    first = next((x for x in map(extract, _head_records(path)) if x), None)
    last = [x for x in map(extract, _tail_records(path)) if x]
    return first, (last[-1] if last else first)


def claude_user_text(record):
    if record.get("type") != "user" or record.get("isMeta") or record.get("isCompactSummary") or record.get("isSidechain"):
        return ""
    content = (record.get("message") or {}).get("content")
    if isinstance(content, list):
        if any(isinstance(p, dict) and p.get("type") == "tool_result" for p in content):
            return ""
        content = " ".join(p.get("text", "") for p in content if isinstance(p, dict) and p.get("type") == "text")
    return _claude_user_text(content or "") if isinstance(content, str) else ""


def codex_user_text(record):
    payload = record.get("payload") if isinstance(record.get("payload"), dict) else {}
    if record.get("type") != "response_item" or payload.get("type") != "message" or payload.get("role") != "user":
        return ""
    text = "".join(x.get("text", "") for x in payload.get("content") or [] if isinstance(x, dict))
    text = re.sub(r"<image[^>]*>.*?</image>", "", text, flags=re.S).strip()
    return "" if text.startswith(CODEX_WRAPPERS) else text


def claude_candidates(paths):
    """Sessions whose transcript folder encodes one of the paths."""
    found = []
    for cwd in paths:
        folder = claude_project_dir(cwd)
        if not folder.is_dir():
            continue
        for path in sorted(folder.glob("*.jsonl")):
            records = _tail_records(path)
            last = max((parse_time(r.get("timestamp")) for r in records if r.get("timestamp")), default=None)
            titles = [r.get("aiTitle") for r in records if r.get("type") == "ai-title" and r.get("aiTitle")]
            custom = [r.get("customTitle") for r in records if r.get("type") == "custom-title" and r.get("customTitle")]
            first, latest = _ends(path, claude_user_text)
            found.append(Candidate("claude", path, path.stem, str(cwd), last, (custom or titles or [None])[-1],
                                   first_request=first, last_request=latest))
    return found


def codex_titles():
    titles = {}
    index = codex_home() / "session_index.jsonl"
    try:
        with open(index, errors="replace") as handle:
            for line in handle:
                try:
                    entry = json.loads(line)
                except ValueError:
                    continue
                if isinstance(entry, dict) and entry.get("id") and entry.get("thread_name"):
                    titles[entry["id"]] = entry["thread_name"]
    except OSError:
        pass
    return titles


def codex_candidates(paths, days):
    """Sessions whose recorded working directory is one of the paths, in the last days."""
    wanted = {str(p) for p in paths}
    titles = codex_titles()
    found = []
    today = datetime.now(timezone.utc).date()
    root = codex_home() / "sessions"
    for offset in range(days + 1):
        day = today - timedelta(days=offset)
        folder = root / f"{day:%Y}" / f"{day:%m}" / f"{day:%d}"
        if not folder.is_dir():
            continue
        for path in sorted(folder.iterdir()):
            if not path.name.startswith("rollout-"):
                continue
            if path.name.endswith(".zst"):
                found.append(Candidate("codex", path, path.name, None, None, "(compressed, not read)"))
                continue
            first_record = _first_record(path).get("payload") or {}
            cwd = first_record.get("cwd")
            if cwd not in wanted:
                continue
            session_id = first_record.get("id") or path.stem
            records = _tail_records(path, 65536)
            last = max((parse_time(r.get("timestamp")) for r in records if r.get("timestamp")), default=None)
            subagent = bool(first_record.get("parent_thread_id") or first_record.get("agent_path"))
            first, latest = _ends(path, codex_user_text)
            found.append(Candidate("codex", path, session_id, cwd, last, titles.get(session_id), subagent, first, latest))
    return found


def _opencode_requests(db, schema, session_id):
    if schema == 2:
        rows = db.execute("select data from session_message where session_id = ? and type = 'user' order by seq",
                          (session_id,))
        return [t for t in ((_loads(raw) or {}).get("text", "").strip() for raw, in rows) if t]
    users = [mid for mid, raw in db.execute("select id, data from message where session_id = ? order by time_created, id",
                                            (session_id,)) if (_loads(raw) or {}).get("role") == "user"]
    texts = []
    for mid in users:
        parts = [_loads(raw) or {} for raw, in db.execute("select data from part where message_id = ? order by id", (mid,))]
        text = "\n".join(p.get("text", "") for p in parts if p.get("type") == "text" and not p.get("synthetic")).strip()
        if text:
            texts.append(text)
    return texts


def opencode_candidates(paths, days):
    database = opencode_db()
    if not database.is_file():
        return []
    wanted = [str(p) for p in paths]
    cutoff = (datetime.now(timezone.utc) - timedelta(days=days)).timestamp() * 1000
    marks = ",".join("?" * len(wanted))
    found, seen = [], set()
    with connect(database) as db:
        tables = _tables(db)
        for schema, table in ((2, "session_v2"), (1, "session")):
            if table not in tables:
                continue
            rows = db.execute(f"select id, directory, title, time_updated, parent_id from {table} "
                              f"where directory in ({marks}) and time_updated >= ?", (*wanted, cutoff)).fetchall()
            for session_id, directory, title, updated, parent in rows:
                if session_id in seen:
                    continue
                seen.add(session_id)
                requests = _opencode_requests(db, schema, session_id)
                found.append(Candidate("opencode", opencode_path(session_id), session_id, directory, ms_time(updated),
                                       title, bool(parent), requests[0] if requests else None,
                                       requests[-1] if requests else None))
    return found


def antigravity_candidates(paths, days):
    database = antigravity_home() / "conversation_summaries.db"
    if not database.is_file():
        return []
    wanted = {str(p) for p in paths}
    cutoff = datetime.now(timezone.utc) - timedelta(days=days)
    found = []
    with connect(database) as db:
        rows = db.execute("select conversation_id, title, preview, last_modified_time, workspace_uris, "
                          "parent_conversation_id from conversation_summaries").fetchall()
    for conversation_id, title, preview, modified, uris, parent in rows:
        last = parse_time(modified)
        matched = [w for w in _workspace_paths(uris) if w.rstrip("/") in wanted]
        path = antigravity_transcript(conversation_id)
        if not matched or not last or last < cutoff or not path.is_file():
            continue
        first, latest = _ends(path, antigravity_user_text)
        found.append(Candidate("antigravity", path, conversation_id, matched[0], last, title or preview or None,
                               bool(parent), first, latest))
    return found


def grok_candidates(paths, days):
    cutoff = datetime.now(timezone.utc) - timedelta(days=days)
    found = []
    for cwd in paths:
        folder = grok_folder(cwd)
        if not folder.is_dir():
            continue
        for session in sorted(folder.iterdir()):
            summary = _loads((session / "summary.json").read_text(errors="replace")) if (session / "summary.json").is_file() else None
            chat = session / "chat_history.jsonl"
            if not summary or not chat.is_file():
                continue
            last = parse_time(summary.get("last_active_at") or summary.get("updated_at"))
            if not last or last < cutoff:
                continue
            first, latest = _ends(chat, grok_user_text)
            if not first:
                continue
            subagent = str(summary.get("session_kind") or "").startswith("subagent")
            found.append(Candidate("grok", chat, session.name, str(cwd), last,
                                   summary.get("generated_title") or summary.get("session_summary") or None,
                                   subagent, first, latest))
    return found


def muse_candidates(paths, days):
    database = muse_home() / "session-index.db"
    if not database.is_file():
        return []
    wanted = [str(p) for p in paths]
    cutoff = (datetime.now(timezone.utc) - timedelta(days=days)).timestamp() * 1_000_000
    marks = ",".join("?" * len(wanted))
    with connect(database) as db:
        rows = db.execute("select session_id, session_log_path, workspace_root, updated_at_us, effective_long_title, "
                          "title, first_user_prompt, coalesce(msp_parent_session_id, '') from sessions "
                          f"where workspace_root in ({marks}) and updated_at_us >= ? and prompt_count > 0",
                          (*wanted, cutoff)).fetchall()
    found = []
    for session_id, log, root, updated, long_title, title, first, parent in rows:
        path = Path(log or "")
        if not path.is_file():
            continue
        _, latest = _ends(path, muse_user_text)
        found.append(Candidate("muse", path, session_id, root, us_time(updated), long_title or title or None,
                               bool(parent), first, latest or first))
    return found


FINDERS = {"claude": lambda paths, days: claude_candidates(paths), "codex": codex_candidates,
           "opencode": opencode_candidates, "antigravity": antigravity_candidates,
           "grok": grok_candidates, "muse": muse_candidates}


def candidates(harness, paths, days):
    """One harness's sessions for the paths, active in the last days. A store that cannot
    be read gives no candidates and a warning, never a crash."""
    cutoff = datetime.now(timezone.utc) - timedelta(days=days)
    try:
        found = FINDERS[harness](paths, days)
    except (OSError, sqlite3.Error) as exc:
        return [], f"The {harness} session store could not be read ({exc})"
    return [c for c in found if harness == "codex" or (c.last and c.last >= cutoff)], None


def _opencode_ids(ref):
    database = opencode_db()
    if not database.is_file():
        return []
    ids = set()
    with connect(database) as db:
        for table in {"session_v2", "session"} & _tables(db):
            ids.update(row[0] for row in db.execute(f"select id from {table} where id like ?", (ref + "%",)))
    return [opencode_path(i) for i in sorted(ids)]


POOLS = {
    "claude": lambda ref: sorted((claude_home() / "projects").glob(f"*/{ref}*.jsonl")),
    "codex": lambda ref: sorted((codex_home() / "sessions").glob(f"*/*/*/rollout-*{ref}*.jsonl*")),
    "opencode": _opencode_ids,
    "antigravity": lambda ref: sorted((antigravity_home() / "brain").glob(
        f"{ref}*/.system_generated/logs/transcript_full.jsonl")),
    "grok": lambda ref: sorted((grok_home() / "sessions").glob(f"*/{ref}*/chat_history.jsonl")),
    "muse": lambda ref: sorted((muse_home() / "sessions").glob(f"*/*/*/{ref}*/session.jsonl")),
}


def locate(harness, ref, candidates):
    """A transcript path for a session ID, ID prefix, title, or path. Returns
    (path, matches): one path, or None with the ambiguous or empty match list."""
    if Path(ref).expanduser().is_file():
        return Path(ref).expanduser(), []
    pool = []
    if SAFE_REF.match(ref):
        try:
            pool = POOLS[harness](ref)
        except sqlite3.Error:
            pool = []
    if len(pool) == 1:
        return pool[0], []
    if len(pool) > 1:
        return None, pool
    lowered = ref.lower()
    titled = [c.path for c in candidates if c.harness == harness and c.title and lowered in c.title.lower()]
    exact = [c.path for c in candidates if c.harness == harness and c.title and lowered == c.title.lower()]
    if len(exact) == 1:
        return exact[0], []
    if len(titled) == 1:
        return titled[0], []
    return None, titled


READERS = {"claude": read_claude, "codex": read_codex, "opencode": read_opencode,
           "antigravity": read_antigravity, "grok": read_grok, "muse": read_muse}


def read(harness, path):
    if str(path).endswith(".zst"):
        raise ValueError("compressed transcript (.zst) not read; the standard library has no zstd")
    try:
        return READERS[harness](path)
    except sqlite3.Error as exc:
        raise ValueError(f"the session database could not be read: {exc}")
