---
title: Choosing agent memory across harnesses
type: guide
authors:
  - "Carlos Boeing"
  - "gpt-6 (codex)"
scope: [agent-memory, harness-parity, claude-mem, model-routing, retrieval]
related:
  - guide-claude-mem-setup.md
  - guide-ai-model-and-effort-routing.md
  - guide-project-structure-and-conventions.md
  - ../reference/reference-agent-memory-options.md
---

# Choosing agent memory across harnesses

This guide helps users of several coding harnesses choose how to record and retrieve session knowledge. It recommends testing a cheaper observer before replacing an existing claude-mem store, and evaluating a local alternative when simpler operation matters more than continuous extraction. It is for operators choosing a memory system, not for treating generated memories as project policy.

## Keep capture, retrieval and authority separate

Agent memory has three jobs that need separate checks:

| Job | What it does | What a successful check proves |
|---|---|---|
| Capture | Records activity or extracts useful facts | A new event becomes a persisted record |
| Retrieval | Finds existing records and supplies context | A known fact can be retrieved from another session or harness |
| Authority | Identifies the current approved decision | The answer agrees with current source files and their status |

An MCP connection proves that tools can be discovered. A successful search proves retrieval. Neither proves that new observations are being captured or that a retrieved statement is still current.

Keep approved decisions, project instructions and user-facing documentation in their owning repository. Memory can help find them, but an extracted observation or similarity score does not override the current source. See the [project conventions](guide-project-structure-and-conventions.md).

## Why claude-mem needs an observer

claude-mem's hooks collect session activity. A background observer model turns that activity into structured observations and summaries, which the worker stores in SQLite. Keyword retrieval uses full-text search; semantic retrieval can use a separate embedding system. The observer performs interpretation and compression, not database storage. See the [upstream architecture](https://docs.claude-mem.ai/architecture/overview).

The coding model and observer are separate consumers of capacity. With the Claude provider, observation extraction can consume Claude allowance while a different harness does the coding. Gemini and OpenRouter move extraction to their own API credentials and limits. A local memory store does not imply local inference. See [provider configuration](https://docs.claude-mem.ai/configuration).

If observation capture fails because an allowance is exhausted, test existing-memory retrieval independently. Restarting the worker does not restore the provider's allowance. Choose another approved provider or wait for the reset, and confirm capture resumes with a new record.

## Recommendation

1. **Keep claude-mem when independent extraction is useful.** Preserve the existing store and compare a cheaper supported observer against the current model on the same activity. Change one variable at a time.
2. **Trial local Engram when a smaller runtime is the priority.** Its local core uses a Go binary and SQLite full-text search without a dedicated observer. Agent-authored memories can miss facts that an independent observer would retain.
3. **Trial Basic Memory when readable notes are the priority.** Markdown files make knowledge inspectable and portable. Checkpoint capture differs by harness and is not equivalent to continuous semantic extraction.
4. **Consider MCP Memory Service for automatic-capture requirements.** Verify the exact integration for each harness before choosing it. MCP compatibility alone is not evidence of automatic capture, and extra services and hooks add operational work.

These are candidate choices, not a completed migration or a measured reliability ranking. The [dated options reference](../reference/reference-agent-memory-options.md) records the current implementation details and model candidates.

## Choose the cheapest observer that passes the task

Use the [model-routing guide](guide-ai-model-and-effort-routing.md) to shortlist models by capability, privacy, cost and separate capacity pools. General intelligence and coding scores do not measure memory extraction quality. A subscription entitlement also does not supply an API key for a different provider.

Start with a bounded sample of representative activity and a reviewed list of facts it contains. Include a decision and its reason, a failed approach, an unresolved question, a file path, and a later correction. Compare whether each observer:

- Keeps the decision, reason and outcome without inventing details.
- Preserves paths and identifiers exactly.
- Separates completed work from proposals and unresolved work.
- Handles corrections without presenting both versions as current.
- Produces the record format the installed adapter expects.

Compare API usage and retry counts from the same sample. Include repeated conversation input and any billed reasoning tokens. Escalate when a cheaper model loses necessary facts or fails the format, rather than because it ranks lower on an unrelated benchmark.

For API usage, estimate cost from measured tokens:

```text
cost = input_tokens / 1,000,000 * input_rate
     + output_tokens / 1,000,000 * output_rate
```

Use one provider's input and output rate together. Routing services can offer different prices for the same model on different backends. Verify the route actually used, and do not turn benchmark cost per task into a monthly memory estimate.

## Evaluate a replacement before migrating

Use an isolated test store before changing the active installation. Test capture, retrieval and restoration separately:

| Check | Evidence to retain |
|---|---|
| Capture | A known fact written from each required harness |
| Cross-harness recall | The same fact retrieved from a fresh session in another harness |
| Correction | A changed decision retrieved with the correction and source |
| Concurrent writes | Records from two simultaneous sessions, with neither lost |
| Restart | The same records available after the memory service restarts |
| Backup and restore | An export restored into an empty store and queried successfully |
| Operating cost | Required processes, startup failures, token use and manual intervention |

Agent-written notes still use the current coding agent's tokens. Removing a dedicated observer removes one quota dependency, but can replace it with reliance on the agent remembering to save. Establish the saving procedure in harness instructions and test it before relying on it.

An advertised concurrency test or a recent database fix is useful evidence of engineering work, not proof of superior reliability in another setup. Keep the original store until restoration and recall have been verified.

## See also

- [Sharing claude-mem across harnesses](guide-claude-mem-setup.md)
- [Agent memory options and observer costs](../reference/reference-agent-memory-options.md)
- [AI model and effort routing](guide-ai-model-and-effort-routing.md)
