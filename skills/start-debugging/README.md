# start-debugging

Finds the root cause of a bug, failure, flaky test, or performance regression before any fix. Run it with `/start-debugging`, or ask in plain words: "debug this", "why does X fail", "this got slow". `start-implementation` also hands over to it after a second failed repair.

## What it does

1. Says whether the problem is a production incident. For an incident it proposes mitigation first and records impact and timeline.
2. Builds one fast, repeatable command that fails on this bug, and runs it before forming any theory.
3. Shrinks the reproduction to what the failure needs.
4. Compares with a working case, then shows 3 to 5 ranked hypotheses, each with a prediction that could prove it wrong.
5. Tests predictions one at a time with tagged debug logs, or measures first for a performance problem.
6. In investigate-only mode (`/start-debugging investigate ...`), reports the cause and leaves the workspace as it found it. Otherwise it hands the fix to `start-implementation` with a regression test at a correct seam.
7. Stops after a third failed fix and hands the architecture question to `start-design`.
8. For an incident, drafts a blameless review from [the template](references/incident-review-template.md).

Secrets are redacted in everything the skill shows.

## Sources

Written from two skills, both under the MIT License (see [LICENSE](LICENSE)):

- Matt Pocock's [`diagnosing-bugs`](https://github.com/mattpocock/skills/blob/5beb35b040e3de97e54fa9e386d7e42d15c295c2/skills/engineering/diagnosing-bugs/SKILL.md) at `5beb35b`: the feedback loop first, minimising, ranked falsifiable hypotheses, tagged logs, the performance branch, the seam rule, redaction, and the cleanup checklist.
- Superpowers [`systematic-debugging`](https://github.com/obra/superpowers/blob/2ce8aa15d05bd57213e6f746f953aafb7ded7a8b/skills/systematic-debugging/SKILL.md) at `2ce8aa1`: no fix before root cause, comparison with a working case, and the stop after three failed fixes.

The incident review follows common blameless postmortem practice. Contributing factors are asked as "how" questions, after John Allspaw's [The Infinite Hows](https://www.kitchensoap.com/2014/11/14/the-infinite-hows-or-the-dangers-of-the-five-whys/), rather than one five-whys chain. The toolkit adds the incident classification, investigate-only mode, and the handoffs to `start-implementation` and `start-design`.

Read relevant prior lessons and original product and architecture constraints. Capture reusable diagnostic observations with evidence and uncertainty during investigation. Incident review retains its existing method; a selected retrospective may synthesize process improvements without duplicating the incident report.
