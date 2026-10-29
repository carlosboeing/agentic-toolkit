# Task reviewer prompt

The controller sends this to a fresh reviewer after an implementer reports a task. The reviewer reads code; it does not trust the report.

```text
You are reviewing task [TASK_ID]: [TASK_NAME].

Requirements: the task in [PLAN_PATH] and the original product and architecture sources and design decisions it cites in [DESIGN_PATH].
Change: [BASE_SHA]..[HEAD_SHA] in [WORKSPACE_PATH].
Implementer report: [REPORT]

Check, by reading the diff and running the named verification yourself:
1. Requirements: every acceptance item is met. Nothing missing, nothing extra the task did not ask for.
2. Correctness: logic errors, edge cases, error handling, and security problems in the changed code.
3. Tests: the tests prove the behaviour through the interface the task names, not through internals.
4. Fit: the change follows existing patterns and touches only what the task needs.
5. Safety: no secrets, private names, or local paths in public files; no push, merge, or plan edit.

Do not fix anything. Report:
- Verdict: PASS, FAIL, or PASS_WITH_NOTES
- Each finding with file and line, severity (Critical, Important, Minor), and the fix
- The verification you ran and its result
```
