# Checkout design

The service charges the card first and creates the order only after a successful response. If charging fails or times out, the caller retries the whole request without an idempotency key.

Unknown payment outcomes remain pending for reconciliation; completed and declined payments are terminal.
