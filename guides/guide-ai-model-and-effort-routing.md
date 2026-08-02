---
title: AI model and effort routing
type: guide
authors:
  - "Carlos Boeing"
  - "gpt-5.6-sol (codex)"
scope: [model-routing, claude-code, codex, kimi-code, antigravity, quota, open-weight]
last_reviewed: 2026-08-02
related:
  - ../reference/reference-cross-harness-models.md
  - ../docs/2-design/2026-08-02-four-harness-model-routing-guide-design.md
  - guide-agy-model-and-quota-selection.md
  - ../reference/reference-harness-capability-map.md
---

# AI model and effort routing

Use this guide to choose a harness, model, and effort in under a minute. The aim is sustained high-quality throughput, not winning every task with the strongest model.

The default policy is:

> Start with the cheapest independent capacity pool that can finish the task reliably. Escalate when you observe complexity, not when the task merely sounds important.

Current plan snapshot: Claude Max 5x, ChatGPT Plus, Kimi Allegretto, and Google AI Pro with Antigravity. This snapshot will change. The routing logic should survive those changes; prices, model rosters, quota structures, and benchmarks live in the dated [cross-harness reference](../reference/reference-cross-harness-models.md).

## The short answer

If you don't want to read the rest, use these defaults:

- **Cheap collection, reading, and extraction:** Antigravity with Gemini 3.6 Flash medium. Use Codex Luna low when terminal/repository access matters more than browser or vision.
- **Everyday coding:** Codex Terra medium. Use Claude Sonnet 5 medium/high when Claude Code's skills and hooks fit the repository better, or Kimi K3-256k high to preserve both pools.
- **Hard coding and debugging:** Codex Sol high. Move to max only after a high-effort run has a concrete unresolved ambiguity.
- **Architecture, brainstorming, and final prose judgment:** Claude Opus 5 high. Use xhigh for high-blast-radius decisions; use Fable 5 max only for the rare long-horizon task that justifies its weekly cost.
- **Very large repositories or documents:** Kimi K3-256k high first, then K3 high only when the evidence really exceeds 256k.
- **Visual UI work and browser QA:** Antigravity with Gemini 3.1 Pro high for consequential judgment, Gemini 3.6 Flash high for iteration.
- **Long autonomous runs:** Choose the harness with the freshest independent pool. Antigravity is useful for browser-heavy/background work; Kimi K3-256k and Claude Sonnet 5 are good implementation runners.
- **Quota relief:** Use Gemini Flash, Luna, Kimi K2.7/K3-256k, or a measured open-weight worker. Do not send architecture or final review to a local 12B–30B model just because it is available.

## 60-second chooser

| Task | Start here | Why this is efficient | Escalate when you observe | Independent-pool fallback |
|---|---|---|---|---|
| Search current docs and collect sources | Agy, Gemini 3.6 Flash medium | Fast, visual/browser-capable, separate pool | Sources conflict, the conclusion is consequential, or synthesis crosses domains | Codex Luna low as worker; Kimi K3-256k high as judge |
| Read, extract, classify, or summarize supplied material | Codex Luna low | Very low Codex credit rate and reliable structured handoff when scope is explicit | Missing facts, subtle legal/business meaning, or more than one interpretation | Gemini 3.6 Flash low/medium; local Gemma 4 12B after validation |
| Mechanical code edits, formatting, renames | Codex Luna low | Cheap terminal loop for bounded changes | The edit crosses APIs, changes behavior, or tests fail unexpectedly | Kimi K2.7 Code; Gemini 3.6 Flash medium |
| Everyday feature or test work | Codex Terra medium | Strong coding value without Sol's burn | More than two layers, unclear invariants, or two evidence-backed failed fixes | Claude Sonnet 5 medium/high; Kimi K3-256k high |
| Debugging a cross-layer or intermittent problem | Codex Sol high | Fast frontier coding agent with strong terminal performance | High effort still has competing root causes or high-blast-radius choices | Claude Opus 5 high; Kimi K3 high |
| Architecture or system design | Claude Opus 5 high | Strong judgment, synthesis, and writing | Irreversible/high-cost decision, security boundary, or unresolved trade-off | Codex Sol high; Kimi K3 high |
| Brainstorm and challenge a product idea | Claude Opus 5 high | Strong divergent thinking and critique | The idea spans many systems or needs long-horizon coherence | Kimi K3 high; Gemini 3.1 Pro high for visual products |
| Turn an approved design into an implementation plan | Codex Sol high or Claude `opusplan` | Strong decomposition tied to executable repository evidence | Plan contains unknown APIs or architecture is still unsettled | Kimi K3 high |
| Business writing, handbook content, proposals | Kimi K3-256k high for draft; Claude Opus 5 high for final judge | Kimi preserves scarce Claude capacity; Opus handles consequential polish | Claims, positioning, negotiation, or brand voice can change the outcome | Claude Sonnet 5 high; Codex Terra medium |
| UI design and visual critique | Agy, Gemini 3.1 Pro high with browser/screenshots | Visual judgment and live browser tools outweigh small text-score differences | Design-system architecture or conflicting product constraints | Claude Opus 5 high with browser screenshots |
| Browser QA and visual regression investigation | Agy, Gemini 3.6 Flash high | Fast screenshots, DOM inspection, and separate quota | Root cause crosses app architecture or accessibility/security | Gemini 3.1 Pro high; Codex Terra/Sol for the code fix |
| Code review | Codex Sol high | Strong repository reasoning and fast issue verification | Security, data loss, concurrency, or architectural contract is involved | Claude Opus 5 high as second reviewer |
| Document/design/plan review | Claude Opus 5 high | Better judgment and prose-level contradiction detection | Corpus exceeds comfortable context or claims need fresh research | Kimi K3 high; Gemini Flash worker plus Opus judge |
| Large-repository or long-document analysis | Kimi K3-256k high | Independent pool and lower quota than K3 1M for the same results within 256k | Evidence packet genuinely exceeds 256k after structural search | Kimi K3 high at 1M; Claude Opus/Sonnet 5 at 1M |
| Long autonomous implementation | Claude Sonnet 5 high or Kimi K3-256k high | Good implementation capability without the top-tier burn | Repeated repair loops, unclear architecture, or review finds systemic issues | Agy Sonnet 4.6 Thinking; Codex Terra/Sol depending difficulty |

## Choose effort before you choose a stronger model

Effort labels are provider-specific. “High” on Kimi, Claude, Gemini, and Codex does not represent equal compute.

### Lowest-sufficient-effort rule

1. Use **low** for collection, extraction, classification, mechanical transformations, and a precisely named symbol or file.
2. Use **medium** for ordinary implementation, test writing, structured drafting, and well-scoped analysis.
3. Use **high** for ambiguity, multi-layer reasoning, debugging, architecture, critique, or final synthesis.
4. Use **xhigh/max** only when the task has high blast radius, a high-effort attempt leaves concrete uncertainty, or a benchmarked long-horizon workflow justifies the extra capacity.

Do not raise effort to compensate for a vague prompt. First narrow the goal, provide the relevant evidence, and define success.

### Provider mappings

| Provider | Cheap | Daily | Hard | Exceptional |
|---|---|---|---|---|
| Claude Code | Haiku 4.5; Sonnet 5 low | Sonnet 5 medium/high | Opus 5 high | Opus 5 xhigh or Fable 5 max |
| Codex | Luna low | Terra medium | Sol high | Sol xhigh/max |
| Kimi Code | K2.7 Code or K3-256k low | K3-256k high | K3 high | K3 max only when a high attempt is demonstrably insufficient |
| Antigravity | Gemini 3.6 Flash low | Gemini 3.6 Flash medium/high | Gemini 3.1 Pro high or Sonnet 4.6 Thinking | Opus 4.6 Thinking; note that Agy's Claude roster trails native Claude Code |

## Task recipes

Each recipe separates collection from judgment. “Do not spend it on” identifies the easiest quota waste to avoid.

### Research, reading, and investigation

| Workload | Choose | Why | Use it for | Escalate when | Do not spend it on | Low-quota fallback |
|---|---|---|---|---|---|---|
| Current web research | Gemini 3.6 Flash medium in Agy | Fast, browser/vision capable, separate pool | Finding official docs, dates, prices, product changes, source packets | Sources disagree or the recommendation has material cost/risk | Opus/Fable doing raw search-result collection | Luna low or an Ollama/Groq worker with mandatory source URLs |
| Supplied-document extraction | Luna low | Cheap structured processing | Facts, entities, headings, action lists, comparisons | Meaning is implicit, politically sensitive, or contract-like | Sol max copying fields from a document | Local Gemma 4 12B after a sample accuracy check |
| Repository mapping | Luna low or Kimi K2.7 Code | Low-cost terminal/search loop | Locate files, symbols, tests, call paths, and uncertainties | Mapping requires architectural conclusions or broad skills inflate context | Opus reading an entire repository before `rg`/AST search | K3-256k high when the repository is genuinely large |
| Consequential synthesis | Opus 5 high or K3 high | Stronger judgment after collection | Proposals, design decisions, investigation conclusions | Conflicting constraints remain after one synthesis pass | Asking the judge to repeat every worker search | Sol high as an independent judge |

### Coding and debugging

| Workload | Choose | Why | Use it for | Escalate when | Do not spend it on | Low-quota fallback |
|---|---|---|---|---|---|---|
| Small, deterministic change | Luna low | Cheapest reliable Codex tier | Renames, config edits, snapshots, obvious tests | Behavior changes or an unexpected failure appears | Sol/Opus on boilerplate | K2.7 Code or Gemini Flash medium |
| Ordinary implementation | Terra medium | Best default balance | Features with a clear design, tests, refactors, API wiring | More than two layers or the design has unresolved choices | Sol max before a first implementation attempt | Sonnet 5 medium or K3-256k high |
| Hard implementation | Sol high | Frontier coding plus fast agent wall time | Cross-layer changes, extension behavior, concurrency, migrations | The problem is architectural rather than implementation detail | Max effort on a task that lacks evidence | Opus 5 high or K3 high |
| Debugging | Sol high | Strong hypothesis/test loop | Intermittent failures, toolchain issues, integration bugs | Two evidence-backed hypotheses fail or security/data integrity is involved | Repeating the same prompt at higher effort without new evidence | Terra high, then Opus high from another pool |
| Final code review | Sol high | Strong issue finding and verification | Correctness, tests, compatibility, maintainability | Security, irreversible data changes, or a disputed finding | Luna approving its own broad implementation | Opus 5 high as second opinion |

### Design, planning, and writing

| Workload | Choose | Why | Use it for | Escalate when | Do not spend it on | Low-quota fallback |
|---|---|---|---|---|---|---|
| Brainstorm | Opus 5 high | Strong divergence and challenge | Options, trade-offs, product framing, failure modes | Long-horizon coherence or unusually high stakes | Fable max for a small feature idea | K3 high |
| System design | Opus 5 high | Strong synthesis and prose | Boundaries, contracts, alternatives, risks | Decision is costly to reverse or evidence is incomplete | Designing from summaries without source inspection | Sol high or K3 high |
| Implementation planning | Sol high or `opusplan` | Converts approved intent into executable tasks | File-level plan, tests, checkpoints, rollout | Design questions reappear | Using a cheap model to silently decide architecture | K3 high |
| Documentation and handbook prose | K3-256k high or Sonnet 5 high | Strong writing at lower scarce-pool cost than Opus | Guides, explanations, brand-aligned drafts | Final wording affects customers, negotiation, or policy | Opus on formatting and link cleanup | Terra medium or Gemini Flash high |
| Proposal/final editorial pass | Opus 5 high | Strong judgment, clarity, and contradiction detection | Positioning, claims, final narrative | Facts need external verification | Opus collecting raw facts and then writing from the same bloated session | K3 high judge over a Flash/Luna evidence packet |

### Visual, browser, and artifact work

| Workload | Choose | Why | Use it for | Escalate when | Do not spend it on | Low-quota fallback |
|---|---|---|---|---|---|---|
| UI iteration | Gemini 3.6 Flash high in Agy | Fast screenshot and browser loop | Spacing, responsive states, obvious visual defects | Product/design-system choices conflict | Text-only architecture model guessing what the page looks like | Claude Sonnet with screenshots |
| UI critique or design direction | Gemini 3.1 Pro high | Better visual reasoning | Hierarchy, composition, accessibility, interaction judgment | Decision spans brand, system architecture, and product strategy | Flash finalizing a high-stakes redesign without review | Opus 5 high with captured screenshots |
| Authenticated exploratory browsing | Kimi WebBridge with a suitable model | Uses the real browser session | Admin panels, purchases, logged-in research, form inspection | A destructive action is possible | Any unattended model confirming purchases or deletes | Manual supervision; use the cheapest competent model |
| Presentations, spreadsheets, PDFs | Harness with the dedicated artifact skill; model by reasoning difficulty | Render/edit tooling determines success | Slides, formulas, layout, document conversion | Claims, narrative, or calculations are consequential | Choosing solely by intelligence benchmark | Flash/Terra for extraction; Opus/K3 for final narrative |

## Route by task properties, not by repository name

Use this decision order manually now and preserve it if you automate later:

1. **Required capability:** terminal, browser, vision, real login, artifact tool, skill, hook, long context, or background operation.
2. **Privacy:** local-only, approved cloud, or any provider.
3. **Task class:** collect, transform, implement, debug, decide, or review.
4. **Difficulty signal:** scope, ambiguity, blast radius, and failed evidence-backed attempts.
5. **Context size:** targeted files, under 256k, or genuinely above 256k.
6. **Quota state:** five-hour headroom first, weekly preservation second, independent fallback third.
7. **Escalation:** raise effort, then model tier, then move to an independent frontier pool.

A future router should accept at least these fields:

```yaml
task_class: collect | transform | implement | debug | decide | review
required_capabilities: [terminal, browser, vision, artifact_tools, long_context]
privacy: local | approved_cloud | any
context_class: targeted | under_256k | over_256k
difficulty: bounded | ordinary | hard | exceptional
quota_state: healthy | preserve_weekly | five_hour_exhausted
fallback_order: []
escalation_triggers: []
```

Do not automate a single numeric “intelligence tier.” It will route browser, privacy, quota, and context tasks incorrectly.

## Worker–judge routing

The worker collects. The judge decides.

### Worker contract

Give the worker a narrow request:

- named scope and stop condition;
- required files, symbols, or official source types;
- exact evidence format;
- source links or file locations for every claim;
- uncertainties and contradictions;
- no architecture, recommendation, or final approval;
- a handoff cap of about 1,500 tokens unless the task proves it needs more.

The judge receives the original question plus the compact packet. It samples important evidence, resolves trade-offs, and performs the consequential synthesis. It does not automatically repeat collection.

### When the split saves capacity

The bounded trials behind this guide found:

- Ollama pricing research used about 25.1k Luna tokens for the worker versus 34.9k Sol tokens for a one-pass answer. The worker packet was adequate if a judge supplied the recommendation without browsing again.
- A Penmark flow trace used about 48.0k Luna tokens versus 66.1k Sol tokens. The worker found the correct path; Sol added material architectural risks.
- A broad codebase skill expanded both runs. The routing contract must constrain skill activation and file reads, or the cheaper worker can still burn large context.

Use the split when collection is large but mechanical, the handoff is small, and the judge can sample rather than rediscover. Use one stronger model when the task is small, collection and judgment are interleaved, both models would load the same large instructions, or worker mistakes would force a full restart.

### Good worker–judge pairings

| Worker | Judge | Good fit |
|---|---|---|
| Gemini 3.6 Flash medium | Opus 5 high | Web research, product comparisons, proposal evidence |
| Luna low | Sol high | Repository mapping before architecture, debugging, or review |
| K2.7 Code / K3-256k low | Opus or Sol high | Large code/document collection from an independent pool |
| Local Gemma 4 12B or GPT-OSS 20B | Any frontier judge | Private extraction, classification, logs, first-pass indexing |

## Project playbooks

These are starting points by task difficulty. No repository gets one permanent model.

### `example-org/website`

| Task | Start | Escalate / fallback |
|---|---|---|
| Component, copy, or test with clear acceptance criteria | Terra medium | Sonnet 5 high if skills/hooks fit better; K3-256k high when Codex is tight |
| Visual polish, responsive QA, browser defect | Gemini 3.6 Flash high in Agy | Gemini 3.1 Pro high for design judgment; Sol high for cross-layer code root cause |
| Design system architecture or major redesign | Opus 5 high plus screenshots | Sol high as implementation planner; K3 high as independent reviewer |

### `example-org/handbook`

| Task | Start | Escalate / fallback |
|---|---|---|
| Link checks, formatting, extraction, catalogue updates | Luna low or Gemini Flash low | Local Gemma 4 12B after accuracy sampling |
| New guide or brand-aligned section | K3-256k high or Sonnet 5 high | Opus 5 high for final editorial judgment |
| Brand system, positioning, or conflicting policy review | Opus 5 high | K3 high independent review; Gemini Pro high when visual identity is central |

### `example-org/client-project`

| Task | Start | Escalate / fallback |
|---|---|---|
| Source discovery and evidence collection | Gemini 3.6 Flash medium worker | Luna low if terminal/local docs dominate; preserve citations |
| Investigation synthesis and option analysis | K3 high or Opus 5 high | Sol high for technical feasibility; second frontier judge for disputed claims |
| Client proposal or consequential recommendation | Opus 5 high over a sourced packet | K3 high draft/review; never let a cheap worker make the final claim |

### `life-admin`

| Task | Start | Escalate / fallback |
|---|---|---|
| `/shop` collection, product specs, current price research | Gemini 3.6 Flash medium with browser | Kimi WebBridge for logged-in/local availability; require official sources |
| Purchase comparison and recommendation | K3 high or Opus 5 high over the worker packet | Gemini 3.1 Pro high when visual fit matters |
| Scheduled monitoring, summaries, routine documents | Gemini Flash low/medium or Luna low | Ollama Cloud/local worker after a successful trial; human approval for purchases |

### `penmark`

| Task | Start | Escalate / fallback |
|---|---|---|
| Bounded TypeScript change or unit test | Terra medium | K3-256k high or Sonnet 5 high |
| VS Code/webview integration or flaky behavior | Sol high | Opus 5 high when extension architecture or UX contract is the issue |
| Release/code review, persistence, concurrency, compatibility | Sol high | Opus 5 high as independent reviewer for data loss or architectural risk |

### `penmark/.workbench`

| Task | Start | Escalate / fallback |
|---|---|---|
| Discovery extraction and file/symbol evidence | Luna low worker | K3-256k low/high for large private context |
| Brainstorm, design, or ADR | Opus 5 high | K3 high independent challenge; Gemini Pro high for visual designs |
| Approved implementation plan or cross-document review | Sol high or Opus 5 high | Use the other as reviewer; do not plan while architecture remains unsettled |

### `reference-workflow`

| Task | Start | Escalate / fallback |
|---|---|---|
| Prompt/rule mechanical change and tests | Terra medium | K3-256k high |
| Router, orchestration, retry, or context architecture | Opus 5 high for design; Sol high for implementation | K3 high as independent long-context reviewer |
| Long autonomous workflow validation | Agy or Kimi on a bounded scenario | Sol/Opus review the trace; never infer reliability from one happy path |

### `example-project`

| Task | Start | Escalate / fallback |
|---|---|---|
| Current hardware/model/provider research | Gemini 3.6 Flash medium worker | Opus/K3 judge when it affects a purchase |
| Docker, LiteLLM, Ollama, or driver implementation | Terra medium | Sol high for ROCm/CUDA/container debugging |
| GPU purchase, privacy architecture, or buy-versus-rent decision | Opus 5 high with refreshed prices and measurements | Sol high technical review; rent the target VRAM class before buying |

## Quota pacing

Five-hour limits affect today's flow. Weekly limits affect whether Friday's hard task still has a frontier model.

### Start of a work block

1. Check the relevant pool before a long task: Claude `/usage`, Codex `/status`, Kimi `/usage`, Agy `/usage` or `/quota`.
2. Decide whether today's work is collection, implementation, or consequential judgment.
3. Reserve one frontier pool for unexpected debugging or review.
4. Use a separate pool for bounded background work.

### Preserve weekly capacity

- Do not use Fable 5, Opus 5 xhigh/max, or Sol max for mechanical work.
- Prefer K3-256k over K3 1M whenever the evidence fits within 256k.
- Avoid changing Kimi model or effort mid-session because the switch invalidates the cache; start a fresh session for a materially different task.
- Start fresh when the conversation contains obsolete investigation, repeated failed attempts, or a large completed phase. Compaction helps continuity but cannot make irrelevant context free.
- Keep raw research out of the judge's main session. Hand over a sourced packet.

### Low-quota fallback order

1. Lower effort if the task is still bounded.
2. Move collection to Gemini Flash, Luna, Kimi K2.7/K3-256k, or a validated open-weight worker.
3. Move the whole task to an independent paid pool at the same capability level.
4. Split collection from judgment if the handoff will be small.
5. Defer non-urgent frontier judgment until reset rather than accepting a low-confidence decision.

Do not chase a five-hour reset by starting the same investigation in three harnesses. That duplicates context and leaves three half-informed sessions.

## Local and hosted open-weight routing

Treat open-weight inference as an extra worker pool.

### Useful now

- **Ollama Cloud Pro:** run a one-month instrumented trial for research packets, repository maps, extraction, first drafts, and test-log triage. Its US$20 price is attractive, but the absolute allowance and overage rates are unpublished.
- **Groq:** use GPT-OSS 20B/120B or Qwen 3.6 for very fast, metered workers when low latency matters.
- **OpenRouter:** use when you want model breadth, provider fallbacks, price/latency routing, budget caps, or Zero Data Retention filtering.
- **RunPod:** rent a 24 GB or 48 GB NVIDIA GPU before buying hardware for a model that does not fit the current 16 GB plan.

### GPU decision

The RTX 5060 Ti 16 GB is the safer home server purchase: lower power, mature NVIDIA container support, and enough VRAM for Gemma 4 12B, GPT-OSS 20B, and tightly configured coding models. The RX 7900 XTX 24 GB opens useful 27B–30B quantizations, but its 355 W board power, AMD's 800 W PSU recommendation, ROCm 7 requirement, and greater heat make it a system upgrade rather than a simple GPU swap.

Do not buy either card to replace Opus, Sol, K3, or Gemini Pro. Buy for privacy, offline work, predictable high-volume workers, or measured cloud spend. See the [reference's deployment section](../reference/reference-cross-harness-models.md#open-weight-and-hosted-quota-relief-options) for models and economics.

### Local escalation contract

Accept a local result without frontier review only when all of these are true:

- the output is mechanically verifiable;
- errors are cheap to detect and reverse;
- the task has no consequential ambiguity;
- a sample has already established adequate accuracy;
- privacy or volume justifies the local path.

Everything else receives a frontier judge or stays on a frontier model end to end.

## Common routing mistakes

- **Picking by benchmark rank alone:** harness tools, active time, quota, and task fit can dominate a one-point score difference.
- **Using max effort as a default:** effort can move benchmark capability substantially, but it also multiplies time and allowance use.
- **Treating subscriptions like API balances:** exact token value cannot be inferred from a five-hour message range.
- **Using 1M context because it exists:** targeted search plus a compact packet is usually cheaper and more accurate.
- **Switching Kimi models repeatedly:** cache invalidation makes apparent variety expensive.
- **Calling a VRAM fit a useful deployment:** leave room for runtime and KV cache, then test the actual context and tool loop.
- **Letting a worker decide:** cheap collection is valuable; cheap unreviewed judgment is where savings turn into rework.
- **Repeating collection in the judge session:** sample the packet. If you must redo everything, the split failed.

## Refresh procedure

When plans or models change:

1. Refresh the [cross-harness reference](../reference/reference-cross-harness-models.md) from official rosters, pricing pages, quota docs, and current independent benchmarks.
2. Update the current-plan snapshot and remove retired model names.
3. Run one bounded task if a new model is supposed to replace an existing routing role.
4. Change this guide only when the evidence changes a start choice, escalation trigger, fallback, or deployment verdict.

The model names will age. The durable policy is to separate capability, harness fit, allowance, and task difficulty—then spend the strongest model only where it changes the outcome.
