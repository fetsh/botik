# Changelog

## 1.0.0 (2026-09-30)

A complete rewrite. See [docs/upgrading.md](docs/upgrading.md).

- `Botik::Bot`: a class per bot with its own configuration, routes, middleware and API client; bots can be subclassed.
- A routing DSL: `command`, `callback` (with `:param`/`*splat` patterns), `text`, `message`, `on`, `default`, `scope`, `namespace`, and the constraints `chat_type:`, `state:`, `if:`/`unless:`.
- Rails-like controllers: actions, `before/after/around_action`, `rescue_from`, `helper`/`helper_method`, implicit rendering, automatic callback query answers.
- ERB views with HTML/MarkdownV2/text formats, auto-escaping, formatting helpers, partials and keyboards.
- Sessions with pluggable stores, and conversation state.
- A built-in Bot API client (`net/http`, multipart uploads, typed errors); `telegram-bot-ruby` is no longer used.
- A webhook Rack app with secret-token verification, a long-polling runner and asynchronous processing.
- Rails integration: generator, rake tasks, logger and error reporting.
- Test helpers: `Botik::Testing::FakeClient` and update builders.
- Requires Ruby 3.3+.

## 0.1.1

- The last version of the original implementation.
