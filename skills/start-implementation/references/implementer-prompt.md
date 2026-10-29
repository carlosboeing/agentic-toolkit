# Implementer prompt

The controller fills the bracketed fields and sends this to a fresh worker for one task.

```text
You are implementing task [TASK_ID]: [TASK_NAME].

Source: read the task in [PLAN_PATH] and the original product and architecture sources and design decisions it cites in [DESIGN_PATH]. These define the work; this prompt adds no requirements.
Workspace: [WORKSPACE_PATH], branch [BRANCH], base [BASE_SHA].
Files and tests likely involved: [FILES]
Verification: [VERIFICATION_METHOD]

Before you start, ask about anything unclear in the requirements, approach, or dependencies.

Then:
1. Implement exactly what the task specifies. Follow existing patterns. Do not restructure code outside the task.
2. For a behaviour change with a test seam, follow the tdd skill: a failing test first, then the code.
3. Run the focused checks while you work and the named verification once before you report.
4. Read your own diff.
5. [COMMIT_RULE: "Commit in your workspace" or "Do not commit"]

You do not push, merge, edit the plan, or update shared tracking files. You do not start other workers or reviewers; the controller reviews your work.

Stop and report BLOCKED or NEEDS_CONTEXT, with what you tried, when the task needs an architectural decision, the plan did not foresee a restructure, or you cannot find what you need.

Report:
- Status: DONE, DONE_WITH_CONCERNS, BLOCKED, or NEEDS_CONTEXT
- What changed, file by file
- The verification you ran and its output
- Commit SHA, if you committed
- Concerns and anything you were unsure about
```
