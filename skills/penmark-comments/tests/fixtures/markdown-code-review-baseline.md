# Checkout design

The service creates a pending order, charges the card with the caller's idempotency key, and records the outcome in a durable state transition.

Unknown payment outcomes remain pending for reconciliation; completed and declined payments are terminal.
