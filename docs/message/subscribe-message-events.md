# Subscribe Message Events

## Responsibility

`SubscribeMessageEvents` streams durable message-domain changes observed from WhatsApp.

The stream is forward-only. It does not replay events that happened before the stream was consumed. Use `CatchUpEvents` to replay missed durable events by sequence before joining this live stream.

`recipient` is optional. When present, only events for that phone number or WhatsApp chat identity are emitted. Heartbeats are transport keep-alives, not business events.

Poll rows are poll events. WhatsApp chat-session metadata is internal storage
context only and is not duplicated as a message event.

## Events

```text
message.text.sent
message.text.received
message.attachment.sent
message.attachment.received
message.reaction.changed
message.reaction.cleared
```

Attachment events include kind, caption, local path, file size, title, and reply target. They do not carry media bytes.

Reaction events are derived from trusted `ZWAMESSAGEINFO.ZRECEIPTINFO`
transitions. A changed reaction carries the target message id, emoji when
present, the actor JID when WhatsApp exposes it, and the reaction stanza id when
decodable. A cleared reaction is represented as the same reaction change with
`emoji` absent.

Unclassified receipt-info rewrites are not public message events. Delivery,
read, and batch receipt blobs stay internal until they can be mapped to a stable
business event without ambiguity.

## Exhaustive Cases

```text
open all message events -> stream remains open
open recipient-scoped events -> only matching recipient events are emitted
idle stream -> heartbeats only, no business event
send text -> emits message_changed.text
receive text -> emits message_changed.text
send attachment without caption -> emits message_changed.attachment, never empty text
send attachment with caption -> emits attachment with caption
reply text -> event includes reply_to_message_id
reply attachment -> event includes reply_to_message_id
send reaction -> emits message_changed.reaction
replace reaction -> emits message_changed.reaction with the new emoji
clear reaction -> emits message_changed.reaction with no emoji when decodable
delivery/read receipt rewrite -> suppressed unless it is a decodable reaction
poll row -> emitted by poll stream, not message stream
chat-session metadata update -> internal only, not message stream
restart after missed rows -> observer resumes from durable cursor
```

## Classification

Text, attachment, and reaction are mutually exclusive public message changes. If
a WhatsApp row has media metadata, it is an attachment event. If attachment kind
cannot be inferred from a known media type, it is exposed as `document`, not as a
vague public unknown.
