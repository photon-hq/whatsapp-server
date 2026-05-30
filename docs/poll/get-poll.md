# Get Poll

## Responsibility

`GetPoll` returns the current WhatsApp poll snapshot from ChatStorage by `poll_id`.

`poll_id` is the WhatsApp message unique key returned by create, poll events, or a previous poll read on any synced device. The server resolves that id to the current device's local ChatStorage row by stanza id when needed. Blank values are rejected. Missing polls return `notFound`.

## Output

```text
poll_id
question
choices[index, text, vote_count]
allow_multiple_choices
hide_voter_names
```

For inbound peer-created polls, `GetPoll` can decode the local ChatStorage metadata even when WhatsApp's runtime does not expose a mutable poll object. This is intentionally read-only evidence; a readable poll snapshot is not proof that `VotePoll` or `UnvotePoll` can mutate that poll on the current device.

## Exhaustive Cases

```text
get existing single-choice poll -> returns current snapshot
get existing multiple-choice poll -> returns current snapshot
get poll using another synced device's poll_id -> resolves by stanza when the local row exists
blank poll_id -> invalidArgument
empty poll_id -> invalidArgument
malformed poll_id -> invalidArgument
missing poll -> notFound
```
