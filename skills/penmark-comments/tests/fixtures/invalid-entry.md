# Invalid entries

<!--pmk:s aaaaaaaa-->metadata<!--/pmk:s aaaaaaaa-->
<!--pmk:s bbbbbbbb-->empty body<!--/pmk:s bbbbbbbb-->
<!--pmk:s cccccccc-->escaping<!--/pmk:s cccccccc-->
<!--pmk:s dddddddd-->reply<!--/pmk:s dddddddd-->

<!-- pmk:review v1 -->
<!--pmk:c aaaaaaaa
codex (robot) · yesterday
> metadata

Invalid metadata.
-->
<!--pmk:c bbbbbbbb
codex (agent) · 2026-07-22 09:00:00 +10:00
> empty body

-->
<!--pmk:c cccccccc
codex (agent) · 2026-07-22 09:00:00 +10:00
> escaping

Uses --retry without escaping.
-->
<!--pmk:c dddddddd re aaaaaaaa
codex (agent) · 2026-07-22 09:00:00 +10:00
> reply

Replies are not emitted by a v1 writer.
-->
<!-- /pmk:review -->
