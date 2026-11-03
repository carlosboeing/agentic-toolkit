# sync-toolkit

Coordinates toolkit updates across harness installations and selected project repositories. The skill handles scope and exceptions; scripts produce inventories, install files and verify results.

## Operations

- Audit: inspect source and targets, preview exact repository changes and global installation actions.
- Apply: use the existing installer, preserve conflicts and run focused smoke tests.
- Resume: reconcile an existing report with current state, then finish authorized delivery.

Repository rollouts use [`toolkit-rollout.py`](../../scripts/toolkit-rollout.py). Global installation uses [`sync-toolkit.sh`](../../scripts/sync-toolkit.sh) and its registration report. The [script catalog](../../scripts/README.md) documents commands, report scope and exit codes.

The skill never treats installation as proof of publication. Existing custom hooks and unrelated work are preserved. Commits, publication, merges and global configuration changes follow the actual request's authority.

Install the complete skill directory through the [shared installer](../README.md#synchronize-every-authored-skill). A source checkout is needed for root scripts. No separate service or dependency is installed by loading this skill.
