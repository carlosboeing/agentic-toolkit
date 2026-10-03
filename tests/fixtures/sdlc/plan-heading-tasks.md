---
date: 2026-09-24
title: "Heading-form tasks"
type: plan
status: approved
authors: ["Fixture Author"]
---

# Plan with heading-form tasks

Design: [approved-design.md](approved-design.md) (revision 3c9d11e).

## Task 1: refresh stale entries

Depends on: none. Verification: `python3 -m unittest tests.test_warmer`.

## Task 2: skip locked entries

Depends on: Task 1. Verification: `python3 -m unittest tests.test_warmer`.

Coverage: R1 -> Task 1; R2 -> Task 1; R3 -> Task 2.
