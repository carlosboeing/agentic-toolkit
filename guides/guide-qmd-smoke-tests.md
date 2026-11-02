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

# Test document retrieval in a fresh agent session

These checks test whether an agent starts with the current project, searches related repositories when useful and verifies current source files. They distinguish QMD command behavior from the agent's search decisions. They are for users checking a registered lexical index across coding harnesses; they do not measure token savings.

## 1. Check the index

Run these commands in your terminal:

```sh
qmd --index agent-docs status
qmd --index agent-docs collection list
```

Confirm that the intended main and private collections appear, with nonzero document counts. To verify a collection's root and default-inclusion setting, replace `project-docs` with its registered name:

```sh
qmd --index agent-docs collection show project-docs
```

A pending-embeddings message is expected for lexical search. If documents changed since the last refresh, have one indexing writer run:

```sh
qmd --index agent-docs update
```

Working in a project directory does not automatically scope this named index. Agents must select the relevant collections. Two `-c` options search the union of those collections. CLI behavior was checked against QMD 2.8.3 on November 2, 2026; see the [QMD CLI reference](https://github.com/tobi/qmd/blob/v2.8.3/README.md#usage).

## 2. Check a question about the current project

Open a fresh agent session in a registered project. Choose a topic you know its docs cover. This example suits a quota-tracking project; replace "quota resets" with your topic.

```text
════ PROMPT STARTS BELOW THIS LINE ════
What do our docs say about quota resets? Find the relevant documentation, cite the current source files, and show the search commands you used.
════ PROMPT ENDS ABOVE THIS LINE ════
```

The delimiters are not part of the prompt.

Pass when the agent uses QMD with filters for the project's main and private documentation, where registered, and reads the selected files from the current checkout before answering. It should keep routine project questions focused. A broader search is valid when it explains a real gap or dependency.

Fail when the agent searches every collection immediately without a task reason, treats the working directory as a QMD filter, or answers solely from indexed snippets.

## 3. Check automatic discovery across projects

In the same session, ask about a shared tool whose documentation lives in another registered repository. For a setup using CrossRev:

```text
════ PROMPT STARTS BELOW THIS LINE ════
Before changing this project, explain how CrossRev decides whether another review pass is needed and when its loop stops. Find the current documentation, show the search commands, and cite the sources.
════ PROMPT ENDS ABOVE THIS LINE ════
```

The delimiters are not part of the prompt.

Pass when the agent includes CrossRev's collections without asking permission to broaden its search. It may include the current project's integration records and shared toolkit instructions. It must check the current project's configuration before claiming that a shared default applies locally.

Fail when the agent searches only the current project, asks permission merely to read another registered corpus, or presents another repository's decision as a binding local requirement.

If CrossRev is not registered, substitute a dependency or shared tool that is. A missing relevant corpus is a coverage gap, not proof of a search failure.

## 4. Check deliberate reuse of prior work

```text
════ PROMPT STARTS BELOW THIS LINE ════
Search our other engineering projects for similar problems or decisions that could help with the topic we discussed. Show the search commands and explain why each selected source is relevant.
════ PROMPT ENDS ABOVE THIS LINE ════
```

The delimiters are not part of the prompt.

Pass when the agent searches beyond the current project's collections and keeps excluded personal or client collections outside this engineering search. Finding no useful matches is valid. Relevance, current status and ownership matter more than the number of matches.

## 5. Check an excluded collection and source freshness

If your configuration has a personal or client collection excluded from default searches, choose a phrase that appears in one of its documents. Replace the example values below with that phrase and collection name:

```sh
qmd --index agent-docs search "distinctive phrase" --json -n 5
qmd --index agent-docs search "distinctive phrase" --json -n 5 -c personal-docs
```

Pass when the first query contains no result from that excluded collection and the second finds its known document. Other engineering documents may mention the same phrase.

Open one source cited by the agent. Confirm that the current text supports the answer, the cited revision is the active checkout's version and a draft is not presented as an approved decision. A stale indexed snippet must not override the current file.

## Record the result

Keep a short note with the date, harness, project, failed check and search command. If a check fails, distinguish a missing or stale collection from an agent routing error. These smoke tests establish retrieval behavior and source checks; compare equivalent tasks separately to measure exploratory reads, answer quality and token usage.
