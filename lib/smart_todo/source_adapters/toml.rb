# frozen_string_literal: true

require "strscan"

module SmartTodo
  module SourceAdapters
    # Scans TOML for comments with a small hand-rolled tokenizer, in the same spirit as the
    # Go adapter (no dependency on a TOML parser gem, and the ones that exist discard
    # comments anyway).
    #
    # TOML's comment syntax is simple: +#+ runs to end of line, and outside a string it is
    # always a comment — +#+ cannot appear in a bare key, a number, or a date. So the only
    # real work is skipping TOML's four string forms, so that a +#+ inside one is never
    # mistaken for a comment.
    class Toml < Base
      # --- Well-formed strings -------------------------------------------------------
      #
      # Single-line strings cannot contain a literal newline, so both forms stop at `\n`.
      # (Note that a negated character class matches `\n` regardless of the `/m` flag, so
      # excluding \n has to be explicit.)
      BASIC_STRING = /"(?:\\.|[^"\\\n])*"/
      LITERAL_STRING = /'[^'\n]*'/

      # Multi-line strings may hold up to two adjacent quotes just before the closing
      # delimiter: `"""foo""""` is the value `foo"`. The trailing `{0,2}` absorbs those
      # extra quotes into the delimiter so the scanner doesn't leave a stray quote behind.
      #
      # Two details in the basic form: `\\[\s\S]` rather than `\\.` so a line-ending
      # backslash continuation stays part of the escape, and `[\s\S]` rather than the `/m`
      # flag so newline handling reads explicitly at each position.
      MULTILINE_BASIC_STRING = /"""(?:\\[\s\S]|(?!""")[^\\])*"""(?:"{0,2})/
      MULTILINE_LITERAL_STRING = /'''(?:(?!''')[\s\S])*'''(?:'{0,2})/

      # --- Unterminated strings (missing closing delimiter) --------------------------
      #
      # These exist so a malformed string is consumed whole. Without them the scanner falls
      # back to advancing one character at a time, "discovers" a `#` inside the malformed
      # string, and reports it as a live comment.
      #
      # How far each one consumes follows from the grammar: single-line forms stop at
      # end-of-line, since TOML forbids a raw newline in them, while multi-line forms
      # legitimately span lines and so must run to EOF.
      #
      # Scan order matters: the unterminated `"""` form has to be tried before
      # BASIC_STRING, which would otherwise match the leading `""` as an empty string and
      # leave the third quote to be rediscovered as the start of a new one.
      UNTERMINATED_MULTILINE_BASIC_STRING = /"""[\s\S]*/
      UNTERMINATED_MULTILINE_LITERAL_STRING = /'''[\s\S]*/
      UNTERMINATED_BASIC_STRING = /"(?:\\.|[^"\\\n])*/
      UNTERMINATED_LITERAL_STRING = /'[^'\n]*/

      COMMENT = /#[^\r\n]*/

      class << self
        def extensions
          [".toml"]
        end

        def comment_marker
          "#"
        end

        def extract_comments(source)
          # All marker regexes are ASCII, so scanning byte-wise is correct, and it sidesteps
          # invalid-UTF-8 byte sequences raising out of StringScanner entirely.
          #
          # Matches are tagged back as UTF-8 on the way out (TOML is UTF-8 by spec), so a
          # non-ASCII comment body doesn't hand callers a BINARY string to interpolate.
          scanner = StringScanner.new(source.dup.force_encoding(Encoding::BINARY))
          comments = []

          until scanner.eos?
            if (match = scanner.scan(COMMENT))
              comments << match.dup.force_encoding(Encoding::UTF_8)
            elsif scanner.scan(MULTILINE_BASIC_STRING) ||
                scanner.scan(UNTERMINATED_MULTILINE_BASIC_STRING) ||
                scanner.scan(MULTILINE_LITERAL_STRING) ||
                scanner.scan(UNTERMINATED_MULTILINE_LITERAL_STRING) ||
                scanner.scan(BASIC_STRING) || scanner.scan(LITERAL_STRING) ||
                scanner.scan(UNTERMINATED_BASIC_STRING) || scanner.scan(UNTERMINATED_LITERAL_STRING)
              # Skip over string contents so a `#` or quote inside them is never mistaken
              # for a comment or a string boundary.
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
