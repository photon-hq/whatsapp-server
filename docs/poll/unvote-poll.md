# Unvote Poll

## Responsibility

`UnvotePoll` clears the current account's vote on an existing WhatsApp poll and returns the refreshed `Poll` observed after ChatStorage changes.

`poll_id` is required. `client_message_id` is used only by the server mutation policy for idempotency.

`poll_id` may come from another synced device. The server resolves it to this device's local poll row by stanza id before calling the helper. The mutation still depends on WhatsApp's runtime exposing that local row as a mutable poll object. If the poll is readable from ChatStorage but not writable by the current runtime, the server returns `operationNotSupported` and does not report a false success.

## Exhaustive Cases

```text
unvote after single-choice vote -> vote_count returns to zero
unvote after multiple-choice vote -> selected vote_counts return to zero
unvote without prior active vote -> helper accepts and refreshed poll is returned
duplicate client_message_id -> alreadyExists
blank poll_id -> invalidArgument
empty poll_id -> invalidArgument
malformed poll_id -> invalidArgument
missing poll -> notFound
readable but runtime-nonmutable poll -> operationNotSupported
```
