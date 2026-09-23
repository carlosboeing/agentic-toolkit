---
date: 2026-09-24
title: "Duplicate IDs fixture"
type: plan
status: approved
authors: ["Fixture Author"]
---

<!-- negative fixture: duplicate task IDs -->

# Plan with two tasks sharing an ID

Design: [approved-design.md](approved-design.md) (revision 3c9d11e).

- N1: first task. Depends on: none. Verification: `python3 -m unittest tests.test_a`.
- N1: second task with the same ID. Depends on: none. Verification: `python3 -m unittest tests.test_b`.

Coverage: R1 -> N1; R2 -> N1; R3 -> N1.
