# Event Model

## Responsibility

The server observes WhatsApp storage changes, rebuilds the smallest complete business object it can trust, and writes one durable event to the owner domain.

One source change has one public owner. The public stream surface is limited to
helper-supported domains: Message and Poll. Poll changes are poll events and
ordinary message changes are message events. Chat/Group are not public stream
domains.

The public stream is for business changes, not raw database rows. Large or mutable assets are referenced by stable identifiers or local metadata and fetched through read APIs.

Only verified transitions are emitted. If the server cannot rebuild a WhatsApp storage transition into a complete business change, that transition stays internal.

## Domains

```text
Message
- text sent or received
- attachment sent or received
- reaction changed or cleared

Poll
- created
- updated
- vote changed
- options changed
```

## Stream Boundary

Events carry enough information to route, order, and update local state.

Message text and lightweight attachment metadata are included in message events. Attachment bytes are not included in events. Consumers fetch media bytes through a read/download path when needed.

Attachment kind is business-facing. Image/video/document/sticker/contact/location are selected from trusted media metadata. Placeholder storage coordinates do not override a concrete media path.

Poll events carry poll identity, chat identity, actor, time, and the concrete
poll delta. Created, vote/unvote, option-change, and other trusted poll
snapshot changes are emitted as durable poll events. Own poll snapshots and
vote state are derived from complete runtime poll snapshots, not from raw
receipt bytes alone. Peer-created inbound poll creation is decoded from the
owner's local `ZWAMEDIAITEM.ZMETADATA` payload when WhatsApp stores the inbound
poll root as message type `13`.

WhatsApp chat-session rows are used only as internal storage context for
recipient derivation and related Message/Poll parsing. The server does not
contain public Chat/Group stream handlers and `CatchUpEvents` does not emit
Chat/Group frames.

## Classification Rules

Text messages and attachment messages are separate public changes. A message row with media but no text is an attachment message, never an empty text message.

Reaction receipt transitions are message events only when the target message,
emoji/clear state, and stable identifiers can be decoded. Generic receipt-info
rewrites are kept internal to avoid duplicating delivery/read status noise.

Poll-root receipt transitions are poll events only. They are not duplicated as
message receipt events. Peer-created inbound poll rows are poll events, not
empty text or attachment events.

Rows that cannot be rebuilt into a complete trusted business event are retried briefly when related state may still be materializing. After the retry window, they are suppressed or kept internal; they are not emitted as vague public events.

Raw codes, internal flags, row updates, counters, and storage changes that cannot be trusted as complete business events are implementation details. They are not public event names.
