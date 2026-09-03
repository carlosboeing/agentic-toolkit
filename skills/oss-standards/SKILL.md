---
name: oss-standards
description: |
  Alias for repo-standards --oss. Apply the OSS house standard. Prefer /repo-standards. Single source is reference/reference-oss-standards.md.
argument-hint: "[check|fix] [path]"
---

# `oss-standards` - alias for `repo-standards --oss`

Deprecated alias. Use `/repo-standards` - this skill forwards to `repo-standards` with `oss` visibility.

```
  /oss-standards check [path]  ->  /repo-standards check oss [path]
  /oss-standards fix [path]    ->  /repo-standards fix oss [path]
```

Invoke `repo-standards` with `oss` flag. See `skills/repo-standards/SKILL.md` for the full spec.
