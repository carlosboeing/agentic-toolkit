---
title: QMD document retrieval smoke tests
type: guide
authors:
  - "Carlos Boeing"
  - "gpt-6 (codex)"
scope: [qmd, retrieval, harnesses, smoke-tests]
related:
  - ../instructions/CLAUDE.md
  - guide-project-structure-and-conventions.md
---

# Test retrieval with ordinary project questions

These checks test whether durable instructions make an agent find project knowledge without search hints in the user's prompt. They cover private lifecycle records, reuse of earlier work and related repositories. They are for users checking everyday behavior across coding harnesses; token savings require a separate task comparison.

## 1. Start a normal session

Open a fresh agent session at the project root, as you normally would. Paste only the short questions below; keep this guide and its expected behavior out of the agent's context. Do not mention QMD, collection names, document paths, citations or search commands.

Choose a project decision documented in its engineering or lifecycle corpus but not already answered by the startup instructions. The quota example below suits QuotaCap; substitute an equivalent question for another project. Repeat the test on layouts you use:

| Project layout | Expected initial scope |
|---|---|
| Public repo with a nested private documentation clone | Private lifecycle corpus as a primary source, alongside relevant public docs |
| Single repo with a working-memory folder | That folder from the first lookup, even without a separate Git repo |
| Single repo with lifecycle records under `docs/` | The declared documentation and lifecycle roots |
| Custom layout or multiple services | Roots declared in project instructions or the Project Map, checked against disk |

A layout may use one or several QMD collections. Repo visibility does not determine search scope, and missing registration should trigger native discovery of that root rather than omission. Do not create folders or change project layouts for this test.

## 2. Check a question about the current project

```text
════ PROMPT STARTS BELOW THIS LINE ════
Why did we decide to record unused quota when a weekly window closes?
════ PROMPT ENDS ABOVE THIS LINE ════
```

The delimiters are not part of the prompt.

Inspect the agent's tool activity after it answers. Pass when the first document lookup includes the actual engineering and lifecycle roots and the agent reads the relevant current files. For the usual nested private clone, that corpus is a primary source from the public root. A single private repo must work equally well using its declared working-memory or documentation folders. Registered roots use the appropriate QMD collections; unindexed roots use native search immediately.

Fail when it treats lifecycle docs as a fallback after application docs, needs you to identify the ordinary document root, assumes a separate private clone is required, or guesses the project's decision without evidence. If it already has the authoritative answer in its loaded instructions, choose another decision to exercise retrieval.

## 3. Check reuse of earlier work

After the first answer, ask:

```text
════ PROMPT STARTS BELOW THIS LINE ════
Have we solved something like this before?
════ PROMPT ENDS ABOVE THIS LINE ════
```

The delimiters are not part of the prompt.

Pass when the agent uses the previous topic to look for relevant prior work, including other engineering projects, without asking permission to broaden its search. No useful matches is a valid result. Excluded personal or client collections should stay outside an engineering search.

## 4. Check a related repository

For a setup using CrossRev, ask this from the same project root:

```text
════ PROMPT STARTS BELOW THIS LINE ════
How does CrossRev recognize a finding it has already reviewed?
════ PROMPT ENDS ABOVE THIS LINE ════
```

The delimiters are not part of the prompt.

Pass when the agent discovers and reads relevant CrossRev sources automatically. It must distinguish shared behavior from the current project's configuration. Fail when it stays inside the current project despite missing the answer, asks permission just to search the related corpus, or substitutes another project's policy for local requirements. If CrossRev is not registered, ask about another registered dependency or shared tool.

## 5. Check the evidence

Use the tool activity or saved session transcript to see which collections and files the agent searched. Do not add retrieval directions to make a failed attempt pass. After recording a failure, use a new session for a retest once the durable setup has been corrected.

Open one source the agent actually read. Confirm that its current text supports the answer and a draft is not presented as an approved decision. A stale indexed snippet must not override the current checkout. Finding a file is insufficient if the answer misreads its status or rationale.

Keep a short result note with the date, harness, project, question, observed searches and pass or failure. These tests distinguish retrieval behavior from answer quality; record both.

## Diagnose a failed test

Run these yourself after the attempt, rather than asking the agent to follow them during the test:

```sh
qmd --index agent-docs status
qmd --index agent-docs collection list
```

Use `qmd --index agent-docs collection show <name>` to verify the root and default inclusion for each intended collection. Compare coverage with the project's actual declared document roots; do not assume every project needs a main/private pair. The working directory does not scope the named index; repeated `-c` filters select the union of collections. CLI behavior was checked against QMD 2.8.3 on November 2, 2026; see the [QMD CLI reference](https://github.com/tobi/qmd/blob/v2.8.3/README.md#usage).

If documents changed, have one indexing writer run `qmd --index agent-docs update`. A pending-embeddings message is expected for lexical search. Missing or stale collections need a configuration or refresh fix; an agent ignoring correctly registered sources needs a durable routing fix.
