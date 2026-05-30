# Vote Poll

## Responsibility

`VotePoll` casts the current account's vote on an existing WhatsApp poll and returns the refreshed `Poll` observed after ChatStorage changes.

`poll_id` is required. `option_indexes` is required, must contain at least one non-negative index, and must not contain duplicates. For both single-choice and multiple-choice polls, the supplied indexes become the current selection. `client_message_id` is used only by the server mutation policy for idempotency.

`poll_id` may come from another synced device. The server resolves it to this device's local poll row by stanza id before calling the helper. The mutation still depends on WhatsApp's runtime exposing that local row as a mutable poll object. If the poll is readable from ChatStorage but not writable by the current runtime, the server returns `operationNotSupported` and does not report a false success.

## Exhaustive Cases

```text
vote single-choice poll -> selected option vote_count increments
vote multiple-choice poll -> selected option vote_counts increment
change vote -> previous selection is cleared and new selection is applied
duplicate client_message_id -> alreadyExists
blank poll_id -> invalidArgument
empty option_indexes -> invalidArgument
negative option index -> invalidArgument
duplicate option indexes -> invalidArgument
malformed poll_id -> invalidArgument
missing poll -> notFound
readable but runtime-nonmutable poll -> operationNotSupported
```
