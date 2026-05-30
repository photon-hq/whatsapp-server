# Send Text API

## Request

Plain text:

```json
{
  "recipient": "8613800138000",
  "content": "Hello WhatsApp"
}
```

Styled text:

```json
{
  "recipient": "8613800138000",
  "content": [
    {
      "text": [
        {
          "text": "Hello "
        },
        {
          "text": "WhatsApp",
          "styles": ["bold"]
        }
      ]
    }
  ],
  "enable_link_preview": false,
  "reply_to": "wamid.HBgMODYxMzgwMDEzODAwMBUCABIYFDNBNjQ=",
  "client_message_id": "msg_20260518_0001"
}
```

List item with mixed normal and styled text:

```json
{
  "recipient": "8613800138000",
  "content": [
    {
      "type": "bullet",
      "text": [
        {
          "text": "Pay "
        },
        {
          "text": "today",
          "styles": ["bold"]
        },
        {
          "text": " before 5pm"
        }
      ]
    }
  ]
}
```

`content` is either a string or an ordered array of text blocks.

## Fields

`recipient`: required phone number. Digits only, includes country code, omits
`+`, 7 to 15 digits.

`content`: required message content. A string is plain text. An array is
structured text. Joined text must not be blank after trimming whitespace.

`enable_link_preview`: optional boolean. Defaults to `false`.

`reply_to`: optional WhatsApp message id to reply to.

`client_message_id`: optional idempotency key.

## Block

A block is one message unit: a normal line, a quote, a bullet item, or a
numbered item.

```json
{
  "type": "bullet",
  "text": [
    {
      "text": "Pay "
    },
    {
      "text": "today",
      "styles": ["bold"]
    }
  ]
}
```

`type`: optional block type. Defaults to `normal`.

`text`: required block text. Use a string for plain block text or an array of
runs for mixed inline styling.

Supported block `type` values:

```json
[
  "normal",
  "quote",
  "bullet",
  "numbered"
]
```

Consecutive `bullet` blocks form a bulleted list. Consecutive `numbered` blocks
form a numbered list.

Block boundaries are layout boundaries. Multiple blocks render as separate
lines or list items. Callers do not need to add trailing newline characters
between blocks.

```json
{
  "recipient": "8613800138000",
  "content": [
    {
      "text": "Intro"
    },
    {
      "type": "bullet",
      "text": "First item"
    },
    {
      "type": "bullet",
      "text": [
        {
          "text": "Second "
        },
        {
          "text": "important",
          "styles": ["bold"]
        },
        {
          "text": " item"
        }
      ]
    }
  ]
}
```

## Run

A run is one contiguous piece of text inside a block.

```json
{
  "text": "WhatsApp",
  "styles": ["bold"]
}
```

`text`: required non-empty string. Preserved exactly.

`styles`: optional inline styles applied to the whole run.

Supported run `styles`:

```json
[
  "bold",
  "italic",
  "strikethrough",
  "code"
]
```

## Whitespace

Whitespace in strings and runs is preserved. Trimming is used only to reject
blank messages.

Valid:

```json
{
  "recipient": "8613800138000",
  "content": "  hello  "
}
```

Invalid:

```json
{
  "recipient": "8613800138000",
  "content": "     "
}
```

## Server Model

The server normalizes every request into ordered text blocks.

```swift
public struct SendTextMessageCommand {
    public let recipient: String
    public let content: [TextBlock]
    public let replyTo: String?
    public let enableLinkPreview: Bool
}

public struct TextBlock {
    public let type: TextBlockType
    public let text: [TextRun]
}

public struct TextRun {
    public let text: String
    public let styles: [TextStyle]
}

public enum TextBlockType {
    case normal
    case quote
    case bullet
    case numbered
}

public enum TextStyle {
    case bold
    case italic
    case strikethrough
    case code
}
```

## Proto

The transport carries normalized text blocks.

```proto
message SendTextMessageRequest {
  string recipient = 1;
  repeated TextBlock content = 2;
  optional string reply_to = 3;
  bool enable_link_preview = 4;
  optional string client_message_id = 100;
}

message TextBlock {
  TextBlockType type = 1;
  repeated TextRun text = 2;
}

message TextRun {
  string text = 1;
  repeated TextStyle styles = 2;
}

enum TextBlockType {
  TEXT_BLOCK_TYPE_NORMAL = 0;
  TEXT_BLOCK_TYPE_QUOTE = 1;
  TEXT_BLOCK_TYPE_BULLET = 2;
  TEXT_BLOCK_TYPE_NUMBERED = 3;
}

enum TextStyle {
  TEXT_STYLE_UNSPECIFIED = 0;
  TEXT_STYLE_BOLD = 1;
  TEXT_STYLE_ITALIC = 2;
  TEXT_STYLE_STRIKETHROUGH = 3;
  TEXT_STYLE_CODE = 4;
}
```

## TypeScript SDK

```ts
export type TextStyle =
  | "bold"
  | "italic"
  | "strikethrough"
  | "code";

export type TextBlockType =
  | "normal"
  | "quote"
  | "bullet"
  | "numbered";

export interface TextRun {
  readonly text: string;
  readonly styles?: readonly TextStyle[];
}

export interface TextBlock {
  readonly type?: TextBlockType;
  readonly text: string | readonly TextRun[];
}

export type TextContent = string | readonly TextBlock[];

export interface SendTextOptions {
  readonly clientMessageId?: string;
  readonly enableLinkPreview?: boolean;
  readonly replyTo?: string;
}
```

```ts
await wa.messages.sendText("8613800138000", "Hello WhatsApp");
```

```ts
await wa.messages.sendText("8613800138000", [
  {
    text: [
      { text: "Hello " },
      { text: "WhatsApp", styles: ["bold"] },
    ],
  },
]);
```

```ts
await wa.messages.sendText("8613800138000", [
  {
    type: "bullet",
    text: [
      { text: "Pay " },
      { text: "today", styles: ["bold"] },
      { text: " before 5pm" },
    ],
  },
]);
```

## SDK Validation

The SDK validates inputs before sending:

- `recipient` is digits only, 7 to 15 digits.
- `content` string must not be blank after trimming.
- `content` array must be non-empty.
- Missing block `type` is normalized to `normal`.
- `block.text` string must be non-empty.
- `block.text` run array must be non-empty.
- `run.text` must be non-empty.
- Joined message text must not be blank after trimming.
- Unknown block types are rejected.
- Unknown run styles are rejected.
- Repeated run styles are normalized to one value.
- Identifier fields are trimmed and must not be blank.
- Text content is never trimmed or rewritten.

## Tests

- Plain string content.
- Normal block with plain string text.
- Normal block with mixed styled runs.
- Bullet block with mixed styled runs.
- Numbered block with mixed styled runs.
- Quote block with mixed styled runs.
- Multiple blocks render as separate message units.
- Multiple styles on one run.
- Repeated run style normalization.
- Leading and trailing whitespace preservation.
- Empty string rejection.
- Empty content array rejection.
- Empty block text rejection.
- Empty run text rejection.
- Blank joined content rejection.
- Unknown block type rejection.
- Unknown run style rejection.
- Emoji and multilingual content.
