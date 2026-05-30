# Catch Up Events

## Responsibility

`CatchUpEvents` replays durable server business events from `server.db`.

It emits events with `sequence > after_sequence`, then emits one terminal `complete` frame with the durable head sequence captured for that call. If `after_sequence` is omitted, replay starts at `0`. If `after_sequence` is at or beyond the current head, only `complete` is emitted.

Use it before reconnecting to a live stream:

```text
remember last handled sequence
call CatchUpEvents(after_sequence: last_sequence)
process replayed events until complete
subscribe to the needed live stream
```

## Events

```text
message_changed
poll_changed
complete
heartbeat
```

Heartbeats are transport keep-alives. Historical WhatsApp rows that predate observer bootstrap are not replayed.

The public catch-up surface is intentionally limited to helper-supported
domains: Message and Poll. `CatchUpEvents` has no `chat_changed` or
`group_changed` payloads.

## Exhaustive Cases

```text
after_sequence omitted -> replays from zero through current head
after_sequence below head -> replays missed events then complete
after_sequence equal to head -> complete only
after_sequence above head -> complete only
message event in range -> emitted as message_changed
message reaction event in range -> emitted as message_changed.reaction
message attachment event in range -> emitted as message_changed.attachment
poll event in range -> emitted as poll_changed
inbound peer-created poll event in range -> emitted as poll_changed.created
poll vote/update/options/end event in range -> emitted as poll_changed with the original change kind
chat/group event-log row in an old server.db -> not emitted; rebuild server.db before validation
```
