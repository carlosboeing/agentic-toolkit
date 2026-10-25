---
name: start-debugging
description: Use when a bug, failure, crash, flaky or slow behaviour, or performance regression needs its cause found, including requests such as "debug this", "investigate", "why does X fail", "this is broken", "this test is flaky", or "this got slow", and when start-implementation hits a second failed repair or a fix with no known cause. Supports an investigate-only mode and a blameless incident review for production incidents. Not for implementing a fix whose cause is already known.
---

# `/start-debugging`

Find the root cause of a bug before any fix. A fix without a confirmed cause treats a symptom.

```text
/start-debugging [description or path]
/start-debugging investigate [description]
/start-debugging help
```

If the entire argument is `help`, `--help`, `-h`, `?`, or `usage`, render this synopsis and stop. `investigate` selects investigate-only mode: report the cause and change nothing.

## Rules for every step

- **Redact.** Write `<REDACTED>` in place of every secret in commands, output, and artifacts you show. Keep credentials in environment variables. Quote only the lines of a captured artifact that carry the signal.
- **No fix before root cause.** Do not edit code to repair anything until the feedback loop confirms the cause.
- **One variable at a time.** Each probe tests one prediction.

## 1. Classify

Say in one line whether this is a production incident: real users are affected (outage, wrong or lost data, security, money), or the user asks for a postmortem. Personal and local bugs are not. The user can decline incident handling.

For an incident, propose mitigation before deep diagnosis: a rollback, a feature flag, or a config change. Any deploy still needs the user's permission. Record impact and timeline facts as they happen; the review needs them.

## 2. Build a feedback loop

This is the most important step. Spend most of the effort here.

Build one command that goes red on this bug, then run it and show the invocation and its redacted output. It must:

- drive the real code path and assert the user's exact symptom, not "runs without error";
- give the same verdict every run, or, for a flaky bug, reproduce at a pinned and useful rate;
- run in seconds;
- run unattended.

Ways to build it, roughly in this order: a failing test at the seam that reaches the bug; an HTTP or CLI call with a fixture input compared to a known-good output; a headless browser script; a replayed captured request or log; a throwaway harness around the failing path; a property or fuzz loop; `git bisect run` between a good and a bad state; the same input through old and new versions.

For a flaky bug, raise the reproduction rate: loop the trigger, add stress, narrow timing windows.

If no loop is possible, stop. List what you tried and ask for access to an environment that reproduces it, a redacted captured artifact, or permission for temporary instrumentation. Do not form theories without a loop.

## 3. Reproduce and minimise

Confirm the loop shows the failure the user described, not a nearby one. Then cut inputs, callers, config, and steps one at a time, rerunning after each cut, until every remaining element is needed for the failure.

## 4. Compare and hypothesise

Find a similar case that works, in this codebase or a known-good version, and list the differences.

Write 3 to 5 ranked hypotheses. Each states its prediction: "If X is the cause, changing Y makes the bug disappear." A hypothesis without a prediction is discarded or sharpened. Show the ranked list to the user, who may re-rank it at once; do not wait if they are away.

## 5. Instrument

Each probe maps to one prediction. Prefer a debugger or REPL, then targeted logs at the boundaries that separate hypotheses. Tag every debug log with one unique prefix, such as `[DEBUG-a4f2]`, so cleanup is one search. Never log everything and search afterwards.

For a performance regression, measure a baseline first, then bisect. Logs are usually the wrong tool.

Repeat steps 4 and 5 until the loop confirms one cause.

## 6. Fix or report

**Investigate-only mode:** remove all instrumentation and throwaway files, confirm the workspace matches its state before the run, and report the cause, the evidence from the loop, and a proposed fix. Stop.

**Fix mode:** hand the fix to `start-implementation` with an in-session plan, so its authorization, verification, and commit rules apply. Before the fix, turn the minimised repro into a failing regression test, but only at a correct seam: the public interface where the test sees the bug pattern as callers trigger it. If no correct seam exists, report that as a finding instead of writing a shallow test. Watch the test fail, apply the fix, watch it pass, then rerun the original loop.

**Stop rule:** after a third failed fix of the same failure, stop fixing. The cause is likely in the architecture. Report what each fix showed and hand the question to `start-design`.

## 7. Clean up

Before reporting done:

- [ ] The original loop no longer reproduces the bug.
- [ ] The regression test passes, or the missing seam is reported.
- [ ] A search for the debug prefix finds nothing.
- [ ] Throwaway harnesses and files are deleted.
- [ ] The commit or PR message states the hypothesis that proved correct.

## 8. Incident review

For an incident, draft a blameless review from [references/incident-review-template.md](references/incident-review-template.md) after the fix. Save it where the project keeps reviews; keep it private by default and redacted. Ask "how" questions about contributing factors instead of one chain of "why". When a factor is in the agent workflow, propose a fix to the skill that allowed it. Each action item becomes a tracker issue, created only with the user's permission.
