# Checkout protocol

The checkout service writes an order and then charges the card. If charging fails, the caller retries the whole request.

## Recovery

Operators delete incomplete orders manually. The design does not define an idempotency key, concurrency behavior, or how a retry distinguishes an incomplete order from a completed one.
