# Subscribe Poll Events

## Responsibility

`SubscribePollEvents` streams durable poll-domain changes observed from WhatsApp.

The stream is forward-only. It does not replay events that happened before the stream was consumed. Use `CatchUpEvents` to replay missed durable events by sequence before joining this live stream.

`poll_id` is optional. Without it, all poll events are emitted. With it, only matching poll events are emitted. Heartbeats are transport keep-alives, not business events.

## Events

```text
poll.created
poll.updated
poll.vote_changed
poll.options_changed
```

Every poll event carries a complete poll snapshot. Own/outbound poll roots are stored as `ZWAMESSAGE.ZMESSAGETYPE=46`. Peer-created inbound poll roots can be stored on the receiver as `ZWAMESSAGE.ZMESSAGETYPE=13` with the created snapshot encoded in `ZWAMEDIAITEM.ZMETADATA`. The stream does not emit partial poll rows.

`vote_changed` is emitted when option vote counts change. `options_changed` is emitted when option text/order changes, including new option additions when WhatsApp exposes them. Other trusted snapshot changes are emitted as `updated`.

## Exhaustive Cases

```text
open all poll events -> stream remains open
open poll-scoped events -> only matching poll_id is emitted
idle stream -> heartbeats only, no business event
poll created -> emits poll_changed.created with complete snapshot
peer-created inbound poll -> emits poll_changed.created with is_from_me=false
own poll vote -> emits poll_changed.vote_changed with updated counts
own poll unvote -> emits poll_changed.vote_changed with updated counts
poll option addition -> emits poll_changed.options_changed when exposed
poll snapshot not ready -> observer retries and does not emit partial event
query current poll -> GetPoll returns the current snapshot
poll root receipt rewrite -> handled here, not duplicated as message receipt
```
