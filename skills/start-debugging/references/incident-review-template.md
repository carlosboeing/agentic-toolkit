# Incident review: <short title>

Blameless: describe what the system and the people saw and did, not who was at fault. Redact secrets and personal data.

## Summary

Two or three sentences: what failed, who it affected, and how it was resolved.

## Impact

- Who was affected, and how many:
- How long:
- What they could not do, or what went wrong (data, money, security):

## Timeline

Times with time zone. Record facts as they happen.

| Time | Event |
|---|---|
| | Started |
| | Detected (how) |
| | Mitigated (how) |
| | Resolved (how) |

## Technical cause

The root cause the feedback loop confirmed, and the evidence.

## Contributing factors

Ask "how", not one chain of "why":

- How did the change pass tests, review, and alarms?
- What slowed detection?
- What slowed mitigation?
- Which factor was in the agent workflow, and which skill rule would have stopped it?

## What went well

## Action items

| Action | Type | Owner | Due | Issue | Done when |
|---|---|---|---|---|---|
| | prevent / detect / mitigate | | | | Verifiable outcome |

Prefer automated safeguards over reminders.
