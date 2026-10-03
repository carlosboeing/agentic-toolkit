---
date: 2026-09-24
title: "Unresolved dependency fixture"
type: plan
status: approved
authors: ["Fixture Author"]
---

<!-- negative fixture: unresolved dependency ID -->

# Plan with a dependency that does not exist

Design: [approved-design.md](approved-design.md) (revision 3c9d11e).

- N1: do the thing. Depends on: N9. Verification: `python3 -m unittest tests.test_thing`.

Coverage: R1 -> N1; R2 -> N1; R3 -> N1.
