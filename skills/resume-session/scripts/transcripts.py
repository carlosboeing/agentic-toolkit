"""Transcript readers for Claude Code and Codex.

Each reader turns one harness's transcript into the same list of events and declares
which kinds of record its harness keeps. Formats are undocumented; they were probed on
Claude Code 2.1.316 and Codex CLI 0.166.0. Unknown record types are counted, not fatal.
"""

import json
import os
import re
from datetime import datetime, timedelta, timezone
from pathlib import Path

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
    yield Event("command", when, command, cwd=workdir)
    if READ_COMMAND.search(command.strip()):
        for match in DOC_PATH.finditer(command):
            yield Event("read", when, "read command", path=_absolute(match.group(1), workdir), cwd=workdir)


def _patch_paths(text):
    return [m.group(1) or m.group(2) for m in PATCH_FILE.finditer(text)]


def _absolute(path, cwd):
    path = os.path.expanduser(path.strip())
    if os.path.isabs(path) or not cwd:
        return path
    return os.path.normpath(os.path.join(cwd, path))


# ---------------------------------------------------------------- finding sessions

class Candidate:
    def __init__(self, harness, path, session_id, cwd, last, title, subagent=False):
        self.harness, self.path, self.session_id = harness, Path(path), session_id
        self.cwd, self.last, self.title, self.subagent = cwd, last, title, subagent


def _tail_records(path, size=262144):
    try:
        with open(path, "rb") as handle:
            handle.seek(0, os.SEEK_END)
            end = handle.tell()
            handle.seek(max(0, end - size))
            data = handle.read().decode("utf-8", errors="replace")
    except OSError:
        return []
    records = []
    for line in data.splitlines()[1 if end > size else 0:]:
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
            found.append(Candidate("claude", path, path.stem, str(cwd), last, titles[-1] if titles else None))
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
            first = _first_record(path).get("payload") or {}
            cwd = first.get("cwd")
            if cwd not in wanted:
                continue
            session_id = first.get("id") or path.stem
            records = _tail_records(path, 65536)
            last = max((parse_time(r.get("timestamp")) for r in records if r.get("timestamp")), default=None)
            subagent = bool(first.get("parent_thread_id") or first.get("agent_path"))
            found.append(Candidate("codex", path, session_id, cwd, last, titles.get(session_id), subagent))
    return found


def locate(harness, ref, candidates):
    """A transcript path for a session ID, ID prefix, title, or path. Returns
    (path, matches): one path, or None with the ambiguous or empty match list."""
    if Path(ref).expanduser().is_file():
        return Path(ref).expanduser(), []
    if harness == "claude":
        pool = sorted((claude_home() / "projects").glob(f"*/{ref}*.jsonl"))
    else:
        pool = sorted((codex_home() / "sessions").glob(f"*/*/*/rollout-*{ref}*.jsonl*"))
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


def read(harness, path):
    if str(path).endswith(".zst"):
        raise ValueError("compressed transcript (.zst) not read; the standard library has no zstd")
    return read_claude(path) if harness == "claude" else read_codex(path)
