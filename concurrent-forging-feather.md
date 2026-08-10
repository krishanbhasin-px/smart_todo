# Fix multi-language TODO scanning review findings

## Context

`/code-review xhigh` was run against the working-tree diff that adds multi-language
(Ruby/Python/Go) TODO scanning via a new `SourceAdapters` abstraction
(`lib/smart_todo/source_adapters.rb`, `lib/smart_todo/source_adapters/{base,ruby,python,go}.rb`)
plus the `CLI`/`CommentParser`/`Todo` changes that route through it. The review (10 parallel
finder passes + live reproduction + a gap-sweep pass) surfaced 15 confirmed issues, ranging from
crashes and silent data corruption/loss to structural duplication, an efficiency gap, and a test
coverage hole. The user asked to fix all of them before this work ships. This plan groups the 15
findings into fix batches, in priority order, with a verification pass at the end.

## Group A — Crashes & correctness bugs (highest priority)

**A1. `comment_parser.rb:16-17` — `^` vs `\A` anchors corrupt Go block-comment TODOs**
Change `@tag_pattern`/`@indent_pattern` to anchor with `\A` instead of `^`. Each entry in the
`comments` array can be a multi-line string (Go's `BLOCK_COMMENT`); `^` matches at every internal
line start, so an embedded `//`-looking line inside a `/* ... */` block gets misdetected as a tag
or continuation line, corrupting/truncating a preceding real Todo or spawning a bogus one.
`\A` restricts the match to the start of the whole comment string, which is what both patterns
are meant to test.

**A2. `cli.rb:96-99` — `adapter_for` crashes on unrecognized/extension-less explicit files**
Old behavior scanned any explicitly-named file as Ruby regardless of extension (e.g. `Rakefile`,
`Gemfile`, `bin/console`, `*.gemspec`). The new code raises an uncaught `ArgumentError` instead.
Fix: fall back to `SourceAdapters::Ruby` when `SourceAdapters.for_extension` returns `nil`,
restoring the old behavior and removing the crash. This also resolves the "should use the
`@errors` convention instead of raising" complaint — there's no error path left to convert.

**A3. `cli.rb:26-33` — adapter extraction errors crash the whole scan**
`SourceAdapters::Python::Error` (e.g. `python3` missing from PATH, non-zero tokenizer exit) and
any Go binary-encoding error (see A4) propagate uncaught out of `parse_file`, aborting the entire
run and discarding TODOs already found in earlier files. Wrap the `parse_file` call in the
`paths.each` loop in a `rescue => e` that appends a message to `@errors` (matching the existing
convention used everywhere else in this class) and `next`s to the following file instead of
crashing.

**A4. `go.rb:27-43` — invalid UTF-8 byte sequences crash `StringScanner`**
`StringScanner#scan` raises `ArgumentError: invalid byte sequence in UTF-8` on non-UTF-8-valid
source, with no rescue anywhere in the call chain. Fix: at the top of `extract_comments`,
`force_encoding(Encoding::BINARY)` on a duped copy of `source` before scanning — all the marker
regexes are ASCII, so byte-wise scanning is correct and sidesteps encoding validity entirely.
Combined with A3, any adapter that still manages to raise now degrades to a per-file error
instead of crashing.

**A5. `go.rb:34-39` — unterminated string/rune literal lets an embedded `//` become a fake comment**
When `INTERPRETED_STRING`/`RUNE_LITERAL`/`RAW_STRING` don't match (unterminated literal), the
scanner falls back to consuming one character at a time, which lets it "discover" a `//` inside
the malformed literal and treat it as a real comment — producing a fully-formed bogus Todo with
metadata parsed from string content. Fix: add unterminated-literal fallback patterns that consume
to end-of-line/EOF without requiring a closing delimiter (Go string/rune literals can't contain a
literal newline, so stopping at `\n` or EOF is correct), e.g.:
```ruby
UNTERMINATED_INTERPRETED_STRING = /"(?:\\.|[^"\\\n])*/m
UNTERMINATED_RUNE_LITERAL       = /'(?:\\.|[^'\\\n])*/m
```
tried after the terminated forms so a well-formed literal is never affected.

**A6. `go.rb:15` — `LINE_COMMENT` leaks a trailing `\r` on CRLF files**
`%r{//[^\n]*}` captures a trailing `\r` on CRLF-encoded source, which ends up embedded in the
Todo's comment body. Change to `%r{//[^\r\n]*}`.

**A7. `python.rb:20-35` — encoding-detection failures silently drop all comments in the file**
`tokenize.detect_encoding()` raises `SyntaxError` *before* yielding any tokens when the source's
first two lines contain a byte invalid for the assumed encoding (no PEP 263 cookie). The
try/except wraps the whole tokenize loop and swallows this the same as a legitimate
trailing-syntax-error case, so the file's real TODOs vanish with zero error reported. Fix: call
`tokenize.detect_encoding` separately, before the tolerant try/except, and let its `SyntaxError`
exit the script non-zero with a message on stderr — which surfaces through the existing
`Open3.capture3` → `raise(Error, ...)` path in `extract_comments`, and then through A3's new
per-file `@errors` handling, instead of vanishing silently.

## Group B — Documentation/behavior alignment

**B1. `README.md` — Go `/* */` TODO claim contradicts the implementation**
`Go.comment_marker` is hardcoded to `"//"` only, so `/* TODO(...) */` is never recognized. Given
the shape of the existing single-`comment_marker`-per-adapter architecture, teaching `Go` to
recognize block-comment tags is a materially bigger change (multi-marker support across
`CommentParser`, `Todo`, and the tag/indent regex construction) for a feature that isn't otherwise
requested. Resolve by correcting the README to state Go TODOs use `//` line-comment syntax only,
removing the false claim, rather than building block-comment tag support. Flag this choice in the
PR description so it's an explicit, visible tradeoff.

## Group C — Structural/consistency cleanups

**C1. `base.rb:40-42` — `glob_pattern` only globs `extensions.first`**
Inconsistent with `SourceAdapters.for_extension`, which checks the full `extensions` array —
currently dormant (every adapter declares exactly one extension) but latent. Fix:
```ruby
def glob_pattern
  "**/*{#{extensions.join(",")}}"
end
```
(brace-glob works fine with a single element too, so no special-casing needed).

**C2. `cli.rb:85-91` — `normalize_path` does one full-tree `Dir[]` walk per adapter**
Combine into a single glob using all registered extensions, e.g.
```ruby
Dir["#{path}/**/*{#{SourceAdapters.all.flat_map(&:extensions).join(",")}}"].sort
```
instead of `SourceAdapters.all.flat_map { |adapter| Dir[...] }.sort`.

**C3. `source_adapters.rb:13-15` — `for_extension` uses `Array#find` where the codebase's
established pattern is a `case` statement**
`Dispatchers::Base.class_for` (lib/smart_todo/dispatchers/base.rb:12-19) resolves its registry via
a plain `case dispatcher; when "slack" ... end` with no dynamic registration. Align
`for_extension` to the same shape for consistency:
```ruby
def for_extension(extension)
  case extension
  when ".rb" then Ruby
  when ".py" then Python
  when ".go" then Go
  end
end
```
(`all` stays as the array, used by `normalize_path`/C2 and anywhere else that needs every adapter.)

**C4. `todo.rb:12` / `comment_parser.rb:17` — duplicated marker/indent derivation**
`Todo#initialize` re-derives indent from raw source with its own `Regexp.escape(marker)` regex,
duplicating logic `CommentParser` already computed via `@indent_pattern`. Have `CommentParser`
compute the tag line's indent once (reusing `@indent_pattern`) and pass it into `Todo.new(source,
filepath, marker:, indent:)`, so `Todo` no longer builds its own indent regex — the two can no
longer silently disagree on what counts as valid indent.

## Group D — Efficiency (lower priority, scoped down)

**D1. `python.rb:46-53` — one `python3` subprocess per file**
Full batching (one process for every Python file across the whole scan) would require CLI-level
restructuring to group files by adapter before parsing and give adapters an optional bulk
extraction path — a materially bigger change than the rest of this plan for a startup-cost win
that only matters on repos with many `.py` files. Given the scope of everything else already in
this batch, implement it narrowly:
- Add `Python.extract_comments_from_files(filepaths)` that spawns *one* `python3` process, passes
  `filepaths` as argv, has the script read+tokenize each path itself, and returns a
  `{filepath => comments}` JSON object.
- In `CLI#run`, when grouping files by adapter, if the adapter responds to
  `extract_comments_from_files`, call it once for that adapter's whole file list and feed each
  file's comments into `CommentParser#parse_comments` directly; otherwise keep the existing
  per-file `parse_file` loop (Ruby/Go, and Python as a fallback if the batch call errors).
- This needs `CommentParser` to expose parsing pre-extracted comments (already possible via the
  private `parse_comments`, so make it `# @api private` public or add a thin `parse_extracted`
  wrapper).

## Group E — Test coverage

Add/extend tests alongside each fix above rather than as an afterthought:
- `test/smart_todo/comment_parser_test.rb` (or wherever `CommentParser` tests live): a Go
  multi-line block-comment case that used to corrupt a preceding real TODO (A1), verifying the
  `\A` fix and closing the "no end-to-end block-comment test" gap called out by the review — now
  as a regression test proving block comments are correctly *not* treated as tag lines, per B1's
  resolution.
- `test/smart_todo/source_adapters/go_test.rb`: CRLF line-comment case (A6), unterminated-string
  case that used to produce a bogus Todo (A5), and an invalid-UTF-8-byte source case (A4).
- `test/smart_todo/source_adapters/python_test.rb`: a source with an invalid encoding byte and no
  PEP 263 cookie, asserting `Python::Error` is now raised (A7) instead of silently returning `[]`.
- `test/smart_todo/cli_multi_language_test.rb`: an extension-less/unrecognized file (e.g.
  `Rakefile`-style name) falls back to the Ruby adapter instead of crashing (A2), and a scan where
  one file raises (e.g. simulate `python3` missing) still completes and reports the other files'
  TODOs plus a collected error (A3).
- If D1 is implemented, add a batch-extraction test in `python_test.rb` covering multiple files in
  one invocation, including one file that fails to tokenize alongside one that succeeds.

## Verification

1. `bundle exec rake test` (or the repo's configured test task) — full suite green, including all
   new tests above.
2. Manually re-run the specific repro cases from the code review to confirm each is fixed:
   - Go source with a stray `//`-looking line inside a `/* */` block preceding a real TODO → the
     real TODO's `comment` is no longer corrupted with leaked source (A1).
   - `smart_todo smart_todo.gemspec` (or any extension-less/unrecognized explicit file) → no
     longer raises, gets treated as Ruby (A2).
   - Simulate a Python file with an invalid PATH or invalid-encoding source alongside valid Ruby
     files in the same run → run completes with exit code 1, error listed, other files' TODOs
     still dispatched (A3, A7).
   - Go source with invalid UTF-8 bytes → no longer raises `ArgumentError` (A4).
   - Go source with an unterminated string containing `// TODO(...)` → no longer produces a bogus
     Todo (A5).
   - CRLF Go file with a TODO → comment body has no embedded `\r` (A6).
3. `bundle exec rubocop` (if configured) to make sure the touched files still pass lint.
4. Confirm README no longer claims Go supports `/* */` TODO tags (B1).
