# Design: Lint mode for plain TODOs in Python and Go

## Problem

`SmartTodoCop` (`lib/smart_todo_cop.rb`) flags plain `# TODO`/`# FIXME`/`# OPTIMIZE`
comments in Ruby files that aren't valid smart_todo syntax, and tells the author
to convert them. It only works for Ruby because it's a RuboCop cop, hooking
RuboCop's own AST — RuboCop only parses `.rb` files. There is no equivalent
lint-time check for Python or Go, even though `smart_todo`'s CLI already
dispatches events for smart_todos in both languages via
`SourceAdapters::Python`/`SourceAdapters::Go`.

Neither Python nor Go have a plugin mechanism suited to this: Ruff has no
third-party custom-rule API (it's a monolithic Rust binary with a fixed rule
set), and a real golangci-lint custom analyzer requires a separate Go module
and `go/analysis` boilerplate. Both are out of proportion to the problem.

## Goals

- Detect plain (non-smart) `TODO`/`FIXME`/`OPTIMIZE` comments in Python and Go
  source, with the same validation depth as `SmartTodoCop` (malformed syntax,
  invalid events, invalid assignees, etc.), and tell the author to use
  smart_todo syntax instead.
- Reuse the existing validation logic rather than reimplementing per-language
  rules — the DSL-parsing logic inside `SmartTodo::Todo` is already
  language-agnostic (it Prism-parses whatever's inside the parens regardless
  of host language).
- Ship as a standalone check invoked via the `smart_todo` CLI, run alongside
  (not as a plugin for) ruff / golangci-lint / whatever Go linting is already
  configured.
- No regression to the existing Ruby cop or the dispatch pipeline.

## Non-goals

- A real ruff plugin or golangci-lint custom analyzer.
- Line-number reporting (file-level only for v1 — explicitly deferred, see
  Future work).
- Continuation-line grouping for multi-line smart_todos in the new lint path.
  `SmartTodoCop` already only validates comments line-by-line (confirmed: all
  its tests are single-line smart_todos, and RuboCop hands it one `Comment`
  per physical `#` line, with no continuation-line reconstruction). The new
  lint path matches that existing granularity for Python/Go rather than
  introducing more thorough validation than Ruby gets today.
- Detecting Go block comments (`/* TODO ... */`) as regular TODOs. Smart_todo
  syntax in Go is only ever recognized via the `//` marker (see
  `CommentParser`'s `tag_pattern`, built from `adapter.comment_marker`), so
  block comments are out of scope for both valid and invalid detection,
  consistent with existing dispatch behavior.

## Design

### 1. Extract `SmartTodo::Linter` (new file: `lib/smart_todo/linter.rb`)

All of the pattern-matching and validation logic currently in
`RuboCop::Cop::SmartTodo::SmartTodoCop` (lib/smart_todo_cop.rb:14-148) moves
into a plain Ruby class with no RuboCop dependency, parameterized by
`marker:` instead of hardcoding `#`:

```
Linter.new(marker: "#").check(comment_text)
# => nil (no violation)
# => "Don't write regular TODO comments. ..." (violation message)
```

`TODO_PATTERN` becomes marker-aware:
`/^#{Regexp.escape(marker)}\s@?(#{INVESTIGATED_TAGS.join("|")})\b/`

Everything else (`smart_todo?`, `invalid_assignees`, `validate_events`, the
per-event-type validators, the messages) moves over unchanged.

### 2. `SmartTodoCop` becomes a thin adapter over `Linter`

```ruby
def on_new_investigation
  linter = Linter.new(marker: "#")
  processed_source.comments.each do |comment|
    next unless (message = linter.check(comment.text))
    add_offense(comment, message: message)
  end
end
```

`test/smart_todo/smart_todo_cop_test.rb` stays unmodified and must keep
passing unchanged — that's the parity check proving the refactor didn't
change cop behavior or messages.

### 3. New `smart_todo --lint [paths]` CLI mode

`lib/smart_todo/cli.rb`:

- New flag: `opts.on("--lint") { @options[:lint] = true }`.
- `run` branches early on `@options[:lint]`: skips `validate_options!` and the
  whole dispatch pipeline (`process_todos`/`process_dispatches`) — lint needs
  no `--dispatcher`/`--slack_token`.
- New `lint(filepaths)` method:
  - Groups `filepaths` by adapter, reusing existing `adapter_for`.
  - For each file, calls `adapter.extract_comments_from_file(filepath)`
    (existing method, untouched — no adapter changes needed since line
    numbers are out of scope).
  - Runs every extracted comment through
    `Linter.new(marker: adapter.comment_marker).check(text)`.
  - Collects `(filepath, message)` for every non-nil result.
- This bypasses `CommentParser`/`Todo` entirely — the lint path only needs
  raw per-comment text, not grouped multi-line `Todo` objects (see
  Non-goals: no continuation-line grouping).

**Output:** one line per violation, `#{filepath}: #{message}`, to `$stdout`.

**Exit code:** `0` if no violations, `1` otherwise — matches the CLI's
existing `@errors`-based exit convention and ruff/rubocop/golangci-lint norms.

**Error handling:** a file that fails to extract (e.g. `python3` missing,
unparseable source) surfaces via the same `@errors <<` / non-zero-exit
pattern `scan_files` already uses for the dispatch path — no new error
handling mechanism.

### Testing

- New `test/smart_todo/linter_test.rb`: exercises `Linter#check` directly for
  both `#` and `//` markers, covering the same cases as
  `smart_todo_cop_test.rb` (regular TODO, malformed smart_todo, invalid
  event, bad assignee, valid smart_todo → no violation), plus lowercase-tag
  variants and both markers.
- `test/smart_todo/smart_todo_cop_test.rb` — unchanged, must keep passing.
- New CLI test(s) for `--lint` covering Ruby/Python/Go fixture files with
  plain and smart TODOs, asserting stdout content and exit code.

## Future work

- Line-number reporting (`file:line: message`), requiring the adapters'
  `extract_comments`/`extract_comments_from_file(s)` to return
  `[text, line]` pairs instead of bare strings (Ruby: free via Prism
  location; Python: `tok.start[0]` from `tokenize`; Go: running line counter
  in the hand-rolled scanner). Deferred because it's a real contract change
  across all three adapters plus `CommentParser`, and wasn't needed for a
  first useful version of this feature.
