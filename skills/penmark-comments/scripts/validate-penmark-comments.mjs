#!/usr/bin/env node
import fs from "node:fs";
import path from "node:path";
import process from "node:process";

const ID = "[a-z2-7]{8}";
const ID_RE = new RegExp(`^${ID}$`);
const REVIEW_OPEN = "<!-- pmk:review v1 -->";
const REVIEW_CLOSE = "<!-- /pmk:review -->";
const ENTRY_META = /^(.*) \((human|agent)\) · (\d{4}-\d{2}-\d{2} \d{2}:\d{2}(?::\d{2})? [+-]\d{2}:\d{2})$/;

function allMatches(regex, text) {
  regex.lastIndex = 0;
  const matches = [];
  let match;
  while ((match = regex.exec(text)) !== null) {
    matches.push({ match, index: match.index });
  }
  return matches;
}

function lineNumber(text, index) {
  return text.slice(0, index).split("\n").length;
}

function isOwnLine(text, start, end) {
  const lineStart = text.lastIndexOf("\n", start - 1) + 1;
  const nextBreak = text.indexOf("\n", end);
  const lineEnd = nextBreak === -1 ? text.length : nextBreak;
  return text.slice(lineStart, start).trim() === "" && text.slice(end, lineEnd).trim() === "";
}

function add(errors, index, message) {
  errors.push({ index, message });
}

function parseEntries(region, regionOffset, errors) {
  const entries = [];
  const consumed = [];
  const entryPattern = /<!--pmk:c ([\s\S]*?)-->/g;

  for (const { match, index } of allMatches(entryPattern, region)) {
    const absoluteIndex = regionOffset + index;
    consumed.push([index, index + match[0].length]);
    const inner = match[1];
    const lines = inner.split("\n").map((line) => line.replace(/\r$/, ""));
    const first = lines[0] ?? "";
    const idMatch = new RegExp(`^(${ID})$`).exec(first);

    if (/^[a-z2-7]{8} re [a-z2-7]{8}$/.test(first)) {
      add(errors, absoluteIndex, "v1 writer must not emit reply syntax");
      continue;
    }
    if (!idMatch) {
      add(errors, absoluteIndex, `invalid entry ID or line: ${first}`);
      continue;
    }
    if (!ENTRY_META.test(lines[1] ?? "")) {
      add(errors, absoluteIndex, "invalid entry metadata or timestamp");
    }
    if (inner.includes("--")) {
      add(errors, absoluteIndex, "entry contains an unescaped double hyphen");
    }

    let cursor = 2;
    while ((lines[cursor] ?? "").startsWith("> ")) cursor += 1;
    if (lines[cursor] !== "") {
      add(errors, absoluteIndex, "entry requires one blank line before its body");
    } else {
      cursor += 1;
      const body = lines.slice(cursor);
      while (body.at(-1) === "") body.pop();
      if (body.length === 0 || body[0] === "" || body.join("\n").trim() === "") {
        add(errors, absoluteIndex, "entry body must contain prose after exactly one separator line");
      }
    }
    entries.push({ id: idMatch[1], index: absoluteIndex });
  }

  let residue = region;
  for (const [start, end] of consumed.sort((a, b) => b[0] - a[0])) {
    residue = residue.slice(0, start) + residue.slice(end);
  }
  if (residue.trim() !== "") {
    add(errors, regionOffset, "review block contains malformed entry data or reserved pmk residue");
  }
  return entries;
}

function parseAnchors(body, errors) {
  const records = new Map();
  const commentPattern = /<!--([\s\S]*?)-->/g;

  function record(id, kind, side, index, end) {
    const current = records.get(id) ?? { id, kinds: new Set(), spanOpen: [], spanClose: [], rangeOpen: [], rangeClose: [], block: [] };
    current.kinds.add(kind);
    current[side].push({ index, end });
    records.set(id, current);
  }

  for (const { match, index } of allMatches(commentPattern, body)) {
    const whole = match[0];
    const inner = match[1].trim();
    let parsed;
    if ((parsed = new RegExp(`^pmk:s (${ID})$`).exec(inner))) {
      record(parsed[1], "span", "spanOpen", index, index + whole.length);
    } else if ((parsed = new RegExp(`^/pmk:s (${ID})$`).exec(inner))) {
      record(parsed[1], "span", "spanClose", index, index + whole.length);
    } else if ((parsed = new RegExp(`^pmk:b (${ID})$`).exec(inner))) {
      record(parsed[1], "block", "block", index, index + whole.length);
      if (!isOwnLine(body, index, index + whole.length)) add(errors, index, "block anchor must be on its own line");
      const lineBreak = body.indexOf("\n", index + whole.length);
      const nextBreak = lineBreak === -1 ? -1 : body.indexOf("\n", lineBreak + 1);
      const nextLine = lineBreak === -1 ? "" : body.slice(lineBreak + 1, nextBreak === -1 ? body.length : nextBreak);
      if (nextLine.trim() === "") add(errors, index, "block anchor must immediately precede a nonblank target line");
    } else if ((parsed = new RegExp(`^pmk:r (${ID}) ([oc])$`).exec(inner))) {
      const side = parsed[2] === "o" ? "rangeOpen" : "rangeClose";
      record(parsed[1], "range", side, index, index + whole.length);
      if (!isOwnLine(body, index, index + whole.length)) add(errors, index, "range half-pair must be on its own line");
    } else if (/^\/?pmk:/.test(inner)) {
      const rawId = /^\/?pmk:[sbrc]\s+(\S+)/.exec(inner)?.[1];
      add(errors, index, rawId && !ID_RE.test(rawId) ? `invalid ID: ${rawId}` : `unknown or malformed pmk residue: ${inner}`);
    }
  }

  const anchors = new Map();
  for (const record of records.values()) {
    if (record.kinds.size !== 1) add(errors, record.spanOpen[0]?.index ?? record.block[0]?.index ?? record.rangeOpen[0]?.index ?? 0, `duplicate anchor ID across kinds: ${record.id}`);
    const kind = [...record.kinds][0];
    if (kind === "span") {
      if (record.spanOpen.length !== 1 || record.spanClose.length !== 1) {
        add(errors, record.spanOpen[0]?.index ?? record.spanClose[0]?.index ?? 0, `span half-pair or duplicate marker: ${record.id}`);
      } else if (record.spanOpen[0].index >= record.spanClose[0].index) {
        add(errors, record.spanOpen[0].index, `span closer precedes opener: ${record.id}`);
      }
    }
    if (kind === "range") {
      if (record.rangeOpen.length !== 1 || record.rangeClose.length !== 1) {
        add(errors, record.rangeOpen[0]?.index ?? record.rangeClose[0]?.index ?? 0, `range half-pair or duplicate marker: ${record.id}`);
      } else if (record.rangeOpen[0].index >= record.rangeClose[0].index) {
        add(errors, record.rangeOpen[0].index, `range closer precedes opener: ${record.id}`);
      }
    }
    if (kind === "block" && record.block.length !== 1) add(errors, record.block[0]?.index ?? 0, `duplicate block anchor: ${record.id}`);
    anchors.set(record.id, { kind, index: record.spanOpen[0]?.index ?? record.block[0]?.index ?? record.rangeOpen[0]?.index ?? 0 });
  }
  return anchors;
}

function validateDocument(text, file) {
  const errors = [];
  const versionHeaders = allMatches(/<!--\s*pmk:review\s+(v\d+)\s*-->/g, text);
  const unsupported = versionHeaders.find(({ match }) => match[1] !== "v1" || match[0] !== REVIEW_OPEN);
  if (unsupported) {
    add(errors, unsupported.index, `unsupported review format ${unsupported.match[1]}`);
    return { errors, commentCount: 0, file };
  }

  const opens = allMatches(new RegExp(REVIEW_OPEN.replace(/[.*+?^${}()|[\]\\]/g, "\\$&"), "g"), text);
  const closes = allMatches(new RegExp(REVIEW_CLOSE.replace(/[.*+?^${}()|[\]\\]/g, "\\$&"), "g"), text);
  if (opens.length > 1) add(errors, opens[1].index, "more than one review block");
  if (opens.length !== closes.length) add(errors, opens[0]?.index ?? closes[0]?.index ?? 0, "unmatched review block delimiter");

  let body = text;
  let entries = [];
  if (opens.length > 0) {
    const open = opens[0];
    const close = closes.find((candidate) => candidate.index > open.index);
    body = text.slice(0, open.index);
    if (close) {
      const afterClose = close.index + REVIEW_CLOSE.length;
      if (text.slice(afterClose).trim() !== "") add(errors, afterClose, "review block must be at EOF");
      const regionStart = open.index + REVIEW_OPEN.length;
      entries = parseEntries(text.slice(regionStart, close.index), regionStart, errors);
      if (entries.length === 0) add(errors, open.index, "empty review block must be removed");
    }
  }

  const anchors = parseAnchors(body, errors);
  const entryIds = new Map();
  for (const entry of entries) {
    if (entryIds.has(entry.id)) add(errors, entry.index, `duplicate entry ID: ${entry.id}`);
    entryIds.set(entry.id, entry);
  }
  for (const [id, anchor] of anchors) {
    if (!entryIds.has(id)) add(errors, anchor.index, `orphan anchor without entry: ${id}`);
  }
  for (const [id, entry] of entryIds) {
    if (!anchors.has(id)) add(errors, entry.index, `orphan entry without anchor: ${id}`);
  }
  return { errors, commentCount: entries.length, file };
}

function validatePath(file) {
  const text = fs.readFileSync(file, "utf8");
  return validateDocument(text, file);
}

const files = process.argv.slice(2);
if (files.length === 0) {
  process.stderr.write("Usage: validate-penmark-comments.mjs FILE [...]\n");
  process.exit(2);
}

let invalid = false;
for (const file of files) {
  try {
    const result = validatePath(file);
    if (result.errors.length === 0) {
      process.stdout.write(`OK ${file}: ${result.commentCount} comments\n`);
      continue;
    }
    invalid = true;
    for (const error of result.errors) {
      process.stderr.write(`${file}:${lineNumber(fs.readFileSync(file, "utf8"), error.index)}: ${error.message}\n`);
    }
  } catch (error) {
    process.stderr.write(`${path.resolve(file)}: ${error.message}\n`);
    process.exitCode = 2;
  }
}
if (process.exitCode !== 2) process.exitCode = invalid ? 1 : 0;
