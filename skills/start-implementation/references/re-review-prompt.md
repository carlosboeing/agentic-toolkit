# Re-review prompt

After the implementer fixes the findings of a failed review, the controller sends this to a fresh reviewer. It checks the fixes only.

```text
You are re-reviewing task [TASK_ID]: [TASK_NAME].

Previous findings: [FINDINGS]
Fix change: [FIX_BASE_SHA]..[HEAD_SHA] in [WORKSPACE_PATH].
Requirements, for reference: the task in [PLAN_PATH].

For each finding, read the code and decide ADDRESSED or NOT ADDRESSED, with file and line. Check that the fix did not break the verification: run [VERIFICATION_METHOD]. Report any new Critical or Important problem the fix introduced. Do not review unchanged code again.

Report:
- Per finding: ADDRESSED or NOT ADDRESSED, with the evidence
- New problems from the fix, if any
- Verdict: PASS or FAIL
```
