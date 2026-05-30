# Send Media Message

## Responsibility

`SendMediaMessage` sends one image or video to a 1:1 WhatsApp chat by phone number and returns the sent `Message` after ChatStorage shows a successful send/upload state.

`recipient` is digits only, includes country code, and omits `+`. `data` is required. `caption`, `accessibility_text`, and `client_message_id` are optional. `client_message_id` is used only by the server mutation policy for idempotency.

## Output

Success returns a full `Message` snapshot for the stored media row. The durable message stream later emits the same row as `message_changed.attachment`.

Attachment events include:

```text
message_id
kind: image | video | audio | voice | document | sticker | contact | location
caption
local_path
file_size
title
reply_to_message_id
```

## Exhaustive Cases

```text
send image without caption -> returns Message; event kind is image
send image with caption -> returns Message; event caption is populated
send image with accessibility text -> returns Message
send video without caption -> returns Message; event kind is video
send video with caption and accessibility text -> returns Message
list recent after media -> returns the full media message metadata
duplicate client_message_id -> alreadyExists
empty data -> invalidArgument
unspecified media type -> invalidArgument
unsupported media type -> invalidArgument
recipient with plus -> invalidArgument
short recipient -> invalidArgument
blank caption -> invalidArgument
blank accessibility_text -> invalidArgument
helper accepts but ChatStorage never shows successful upload -> deadlineExceeded
```

## Notes

Media bytes are staged locally before the helper command and removed after the helper returns. Events carry lightweight metadata only; they do not carry media bytes.
