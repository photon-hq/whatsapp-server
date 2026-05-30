# Send Reaction

## Responsibility

`SendReaction` sends the current account's emoji reaction to an existing WhatsApp message by message id and returns the reacted `Message` after ChatStorage shows the reaction state.

`message_id` is the target WhatsApp `WAMessage.uniqueKey`. `emoji` is required and must not be blank. `client_message_id` is used only by the server mutation policy for idempotency.

## Exhaustive Cases

```text
prepare target message -> target message_id exists
send thumbs-up reaction -> returns reacted Message
send heart reaction -> returns reacted Message
send laugh reaction -> returns reacted Message
send multicodepoint emoji reaction -> returns reacted Message
replace reaction on same target -> returns reacted Message
duplicate client_message_id -> alreadyExists
blank message_id -> invalidArgument
blank emoji -> invalidArgument
missing target message -> notFound
helper accepts but ChatStorage never shows the reaction -> deadlineExceeded
```

## Notes

The public message stream emits reaction changes when the receipt-info transition can be decoded into a stable target message, emoji/clear state, and reaction identifiers.
