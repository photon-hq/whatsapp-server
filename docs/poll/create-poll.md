# Create Poll

## Responsibility

`CreatePoll` creates a WhatsApp poll in a 1:1 chat by phone number and returns the refreshed `Poll` observed in ChatStorage.

`recipient` is digits only, includes country code, and omits `+`. `question` and every choice are trimmed; empty values are rejected. At least two choices are required. `allow_multiple_choices` and `hide_voter_names` map directly to WhatsApp poll settings. `closes_at`, when present, must be in the future and is passed to WhatsApp as the poll end time. `client_message_id` is used only by the server mutation policy for idempotency.

## Output

```text
poll_id
question
choices[index, text, vote_count]
allow_multiple_choices
hide_voter_names
```

## Exhaustive Cases

```text
create default poll -> returns poll snapshot
trim question and choices -> returns trimmed values
unicode question/choices -> returns Poll
allow multiple choices -> returned poll has allow_multiple_choices true
hide voter names -> returned poll has hide_voter_names true
future close time -> returns Poll
duplicate client_message_id -> alreadyExists
recipient with plus -> invalidArgument
short recipient -> invalidArgument
blank question -> invalidArgument
zero choices -> invalidArgument
one choice -> invalidArgument
blank choice -> invalidArgument
past close time -> invalidArgument
```
