# Design: cache warmer (approved)

Revision: 3c9d11e

Requirements:

- **R1**: the warmer refreshes entries older than the configured TTL. Independent.
- **R2**: the warmer logs one summary line per run. Independent.
- **R3**: the warmer skips entries locked by another process. Dependent on R1 landing first.
