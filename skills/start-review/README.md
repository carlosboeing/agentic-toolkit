# start-review

Assess fidelity to intent and readiness using the project's review methods. This entry coordinates review; it creates no competing review engine.

Run `/start-review [artifact, change, or delivery scope] [help]` or request its work in natural language. Use `/start-review help` for the synopsis.

The complete procedure is in [SKILL.md](SKILL.md). Project instructions own storage, review, and delivery permissions. Documents, separate sessions, and agents are conditional. The skill stops at its requested boundary unless an explicit workflow already authorizes continuation.

## Dependencies and installation

No additional runtime or service is required. Use the available project and harness capabilities; unavailable capabilities are reported rather than simulated. Git, Bash, and `rsync` are needed for the toolkit installation procedure. Install the complete directory using the [shared instructions](../README.md#install-one-skill). No global installation is performed by invoking this phase.
