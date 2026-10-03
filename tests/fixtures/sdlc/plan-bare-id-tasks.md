---
date: 2026-09-24
title: "Bare ID tasks"
type: plan
status: approved
authors: ["Fixture Author"]
---

# Plan with bare ID lines

Design: [approved-design.md](approved-design.md) (revision 3c9d11e).

T1: refresh stale entries. Depends on: none. Verification: `python3 -m unittest tests.test_a`.

T2: skip locked entries. Depends on: T1. Proof: a reviewer reads the run log.

Coverage: R1 -> T1; R2 -> T2; R3 -> T2.
