# Send Text Message

## Responsibility

`SendTextMessage` sends one text message to a 1:1 WhatsApp chat by phone number and returns the sent `Message` after ChatStorage shows a successful send state.

The request body uses `content`: a plain string or ordered text blocks. See [Send Text API](./send-text-api.md).

`recipient` is digits only, includes country code, and omits `+`. Content preserves caller whitespace but must not be blank after trimming. `reply_to` is an optional WhatsApp message id. `client_message_id` is used only by the server mutation policy for idempotency.

## Output

Success returns a full `Message` snapshot whose `message_id` is the WhatsApp `WAMessage.uniqueKey`:

```text
message_id: WhatsApp WAMessage.uniqueKey
```

The durable message stream later emits the same message as `message_changed.text`.

## Exhaustive Cases

```text
send string content -> returns message_id and stores same text
send block content -> returns message_id and stores joined text
list recent after send -> newest row references returned message_id
send padded text -> returns Message and preserves whitespace
send multiline unicode text -> returns Message
send link preview text -> returns Message when enable_link_preview is true
reply to own message -> returns Message and event carries reply_to_message_id
reply to inbound message -> returns Message and event carries reply_to_message_id
send bold style -> returns Message
send italic style -> returns Message
send strikethrough style -> returns Message
send code style -> returns Message
send bullet block -> returns Message
send numbered block -> returns Message
send quote block -> returns Message
duplicate client_message_id -> alreadyExists
empty string content -> invalidArgument
empty content array -> invalidArgument
empty block text -> invalidArgument
empty run text -> invalidArgument
blank joined content -> invalidArgument
recipient with plus -> invalidArgument
short recipient -> invalidArgument
unknown block type -> invalidArgument
unknown style -> invalidArgument
```
