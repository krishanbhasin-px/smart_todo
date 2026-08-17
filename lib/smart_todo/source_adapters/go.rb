# frozen_string_literal: true

require "strscan"

module SmartTodo
  module SourceAdapters
    # Scans Go source for comments with a small hand-rolled tokenizer (no dependency on
    # a Go toolchain). Go's comment syntax is simple enough — +//+ line comments, +/* */+
    # block comments (never nested), and three literal forms that can hide a stray +//+
    # or +/*+ — that a lightweight scanner is both correct and cheap to maintain.
    class Go < Base
      # Go string and rune literals cannot contain a literal newline, so these stop at `\n`:
      # left unbounded, the negated class (which matches `\n` regardless of the `/m` flag)
      # would let a malformed, unterminated literal consume past its line and swallow a
      # genuine `// TODO` on a later line before finally closing on some later quote.
      INTERPRETED_STRING = /"(?:\\.|[^"\\\n])*"/
      RUNE_LITERAL = /'(?:\\.|[^'\\\n])*'/
      RAW_STRING = /`[^`]*`/m
      # Fallback forms for an unterminated literal (missing closing delimiter): Go string/rune
      # literals can't contain a literal newline, so consuming to end-of-line/EOF without a
      # closing delimiter is correct, and prevents the scanner's char-by-char fallback from
      # "discovering" a `//` inside the malformed literal and treating it as a real comment.
      UNTERMINATED_INTERPRETED_STRING = /"(?:\\.|[^"\\\n])*/
      UNTERMINATED_RUNE_LITERAL = /'(?:\\.|[^'\\\n])*/
      # Fallback forms for an unterminated raw string (missing closing backtick) or block
      # comment (missing closing `*/`): both can legitimately span multiple lines, so unlike
      # the string/rune fallbacks above, these must consume all the way to EOF rather than
      # stopping at the first newline, for the same reason — otherwise the char-by-char
      # fallback could surface an embedded `// TODO(...)` inside the malformed literal/comment
      # as a live one.
      UNTERMINATED_RAW_STRING = /`.*/m
      UNTERMINATED_BLOCK_COMMENT = %r{/\*.*}m
      LINE_COMMENT = %r{//[^\r\n]*}
      BLOCK_COMMENT = %r{/\*.*?\*/}m

      class << self
        def extensions
          [".go"]
        end

        def comment_marker
          "//"
        end

        def extract_comments(source)
          # All marker regexes are ASCII, so scanning byte-wise is correct and sidesteps
          # invalid-UTF-8 byte sequences raising out of StringScanner entirely.
          scanner = StringScanner.new(source.dup.force_encoding(Encoding::BINARY))
          comments = []

          until scanner.eos?
            if (match = scanner.scan(LINE_COMMENT) || scanner.scan(BLOCK_COMMENT))
              comments << match
            elsif scanner.scan(RAW_STRING) || scanner.scan(INTERPRETED_STRING) || scanner.scan(RUNE_LITERAL) ||
                scanner.scan(UNTERMINATED_INTERPRETED_STRING) || scanner.scan(UNTERMINATED_RUNE_LITERAL) ||
                scanner.scan(UNTERMINATED_RAW_STRING) || scanner.scan(UNTERMINATED_BLOCK_COMMENT)
              # Skip over literal contents so a `//`, `/*`, or quote inside them is
              # never mistaken for a comment or string boundary.
            else
              scanner.getch
            end
          end

          comments
        end
      end
    end
  end
end
