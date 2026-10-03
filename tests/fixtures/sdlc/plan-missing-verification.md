---
date: 2026-09-24
title: "Missing verification fixture"
type: plan
status: approved
authors: ["Fixture Author"]
---

<!-- negative fixture: task without verification evidence -->

# Plan with a task that proves nothing

Design: [approved-design.md](approved-design.md) (revision 3c9d11e).

- N1: do the thing. Depends on: none. Verification: `python3 -m unittest tests.test_thing`.
- N2: do the other thing with no evidence at all. Depends on: N1.

Coverage: R1 -> N1; R2 -> N2; R3 -> N1.
