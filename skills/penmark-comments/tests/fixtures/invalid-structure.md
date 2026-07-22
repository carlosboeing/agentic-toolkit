# Invalid structure

<!--pmk:s badid999-->bad ID<!--/pmk:s badid999-->
<!--pmk:s abcdefgh-->first<!--/pmk:s abcdefgh-->
<!--pmk:s abcdefgh-->duplicate<!--/pmk:s abcdefgh-->
<!--pmk:s bbbbbbbb-->missing closer
<!--pmk:r cccccccc o-->
range missing closer
text <!--pmk:b dddddddd--> shares a line
<!--pmk:s eeeeeeee-->anchor without entry<!--/pmk:s eeeeeeee-->

<!-- pmk:review v1 -->
<!--pmk:c abcdefgh
codex (agent) · 2026-07-22 09:00:00 +10:00
> first

Duplicate anchor ID.
-->
<!--pmk:c ffffffff
codex (agent) · 2026-07-22 09:00:00 +10:00
> missing anchor

Entry without anchor.
-->
<!-- /pmk:review -->

Content after the review block is invalid.
