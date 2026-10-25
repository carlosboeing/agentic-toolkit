# handoff

Writes a handoff document so a fresh session can continue the current work. Run it with `/handoff`, optionally followed by what the next session will do. The model never starts it on its own.

The document goes to the project's working-memory notes location, with that location's frontmatter, so the next session finds it in the repository rather than in a memory plugin. A project with no such location gets the file in the OS temporary directory, with a warning that it will not last.

## Source

Adapted from [`handoff`](https://github.com/mattpocock/skills/blob/5beb35b040e3de97e54fa9e386d7e42d15c295c2/skills/productivity/handoff/SKILL.md) in Matt Pocock's skills at commit `5beb35b`, under the MIT License in [LICENSE](LICENSE). Changes: the save location, the commit rule, the non-durable warning, and "call the Skill tool for" became "load", which every harness can follow.
