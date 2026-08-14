# frozen_string_literal: true

require "strscan"

module SmartTodo
  module SourceAdapters
    # Scans Go source for comments with a small hand-rolled tokenizer (no dependency on
    # a Go toolchain). Go's comment syntax is simple enough — +//+ line comments, +/* */+
    # block comments (never nested), and three literal forms that can hide a stray +//+
    # or +/*+ — that a lightweight scanner is both correct and cheap to maintain.
    class Go < Base
      INTERPRETED_STRING = /"(?:\\.|[^"\\])*"/m
      RUNE_LITERAL = /'(?:\\.|[^'\\])*'/m
      RAW_STRING = /`[^`]*`/m
      # Fallback forms for an unterminated literal (missing closing delimiter): Go string/rune
      # literals can't contain a literal newline, so consuming to end-of-line/EOF without a
      # closing delimiter is correct, and prevents the scanner's char-by-char fallback from
      # "discovering" a `//` inside the malformed literal and treating it as a real comment.
      UNTERMINATED_INTERPRETED_STRING = /"(?:\\.|[^"\\\n])*/m
      UNTERMINATED_RUNE_LITERAL = /'(?:\\.|[^'\\\n])*/m
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
                scanner.scan(UNTERMINATED_INTERPRETED_STRING) || scanner.scan(UNTERMINATED_RUNE_LITERAL)
              # Skip over literal contents so a `//`, `/*", or quote inside them is
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
