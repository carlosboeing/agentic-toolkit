import assert from "node:assert/strict";
import { spawnSync } from "node:child_process";
import { fileURLToPath } from "node:url";
import path from "node:path";
import test from "node:test";

const here = path.dirname(fileURLToPath(import.meta.url));
const cli = path.join(here, "validate-penmark-comments.mjs");
const fixtures = path.join(here, "..", "tests", "fixtures");

function run(...args) {
  return spawnSync(process.execPath, [cli, ...args], { encoding: "utf8" });
}

const cases = [
  ["plain.md", 0, /OK .*0 comments/],
  ["valid-all.md", 0, /OK .*3 comments/],
  ["invalid-structure.md", 1, /invalid ID|duplicate|half-pair|own line|EOF|orphan/],
  ["invalid-entry.md", 1, /metadata|body|double hyphen|v1 writer/],
  ["unknown-version.md", 1, /unsupported review format v2/],
];

for (const [name, expectedStatus, expectedOutput] of cases) {
  test(name, () => {
    const result = run(path.join(fixtures, name));
    assert.equal(result.status, expectedStatus, result.stderr || result.stdout);
    assert.match(`${result.stdout}\n${result.stderr}`, expectedOutput);
  });
}

test("requires at least one path", () => {
  const result = run();
  assert.equal(result.status, 2);
  assert.match(result.stderr, /Usage:/);
});
