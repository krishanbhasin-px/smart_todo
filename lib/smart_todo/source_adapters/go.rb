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
      LINE_COMMENT = %r{//[^\n]*}
      BLOCK_COMMENT = %r{/\*.*?\*/}m

      class << self
        def extensions
          [".go"]
        end

        def comment_marker
          "//"
        end

        def extract_comments(source)
          scanner = StringScanner.new(source)
          comments = []

          until scanner.eos?
            if (match = scanner.scan(LINE_COMMENT) || scanner.scan(BLOCK_COMMENT))
              comments << match
            elsif scanner.scan(RAW_STRING) || scanner.scan(INTERPRETED_STRING) || scanner.scan(RUNE_LITERAL)
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
