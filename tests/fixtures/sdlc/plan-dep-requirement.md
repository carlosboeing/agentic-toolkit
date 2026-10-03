---
date: 2026-09-24
title: "Dep requirement fixture"
type: plan
status: approved
authors: ["Fixture Author"]
---

<!-- negative fixture: a design requirement ID in a dependency phrase is not a task dependency -->

# Plan referring to a requirement in prose

Design: [approved-design.md](approved-design.md) (revision 3c9d11e).

- N1: skip locked entries. Depends on: N2, R1. The design lands R1 before R3, so order matters. Verification: `python3 -m unittest tests.test_locks`.
- N2: refresh stale entries. Depends on: none. Verification: `python3 -m unittest tests.test_refresh`.

Coverage: R1 -> N2; R2 -> N2; R3 -> N1.
