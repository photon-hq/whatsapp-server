# List Recent Messages

## Responsibility

`ListRecentMessages` returns recent WhatsApp messages across chats, newest first.

`page_size` is optional; omitted means `50`, and explicit values must be in `[1, 100]`. `page_token`, when present, must be the token returned by the previous response for the same query. `is_from_me`, `before`, and `after` are optional filters.

## Output

The response contains:

```text
messages[]
next_page_token
```

Each `Message` is the same full message shape returned by `GetMessage` and write operations: ids, chat identity, direction, status, text, dates, reply target, media metadata, latest reaction, and receipt digest when present.

## Exhaustive Cases

```text
default page_size -> returns up to 50 rows
page_size 1 -> returns one newest row
page_size 3 -> returns three newest rows
page_size 100 -> returns up to 100 rows
page_size above 100 -> invalidArgument
zero page_size -> invalidArgument
negative page_size -> invalidArgument
is_from_me true -> returns only own messages
is_from_me false -> returns only peer messages
before filter -> returns messages earlier than timestamp
after filter -> returns messages later than timestamp
after >= before -> invalidArgument
valid next_page_token -> returns the next stable page
page_token with changed filters -> invalidArgument
malformed page_token -> invalidArgument
```
