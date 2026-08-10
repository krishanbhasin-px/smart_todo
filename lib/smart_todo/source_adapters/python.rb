# frozen_string_literal: true

require "open3"
require "json"

module SmartTodo
  module SourceAdapters
    # Scans Python source for comments by shelling out to the interpreter's own
    # +tokenize+ module. This reuses CPython's authoritative lexer instead of
    # reimplementing Python's string/f-string/triple-quote escaping rules in Ruby, at
    # the cost of requiring +python3+ on PATH.
    class Python < Base
      class Error < StandardError; end

      # Reads the source to scan from stdin (as bytes, so tokenize can honor a PEP 263
      # encoding declaration) and prints a JSON array of raw comment strings to stdout.
      # Tolerant of trailing syntax errors (e.g. an unterminated string at EOF), matching
      # Prism's leniency for the Ruby adapter: whatever was tokenized before the error is
      # still returned.
      TOKENIZE_SCRIPT = <<~PYTHON
        import io
        import json
        import sys
        import tokenize

        source = sys.stdin.buffer.read()
        comments = []
        try:
            for tok in tokenize.tokenize(io.BytesIO(source).readline):
                if tok.type == tokenize.COMMENT:
                    comments.append(tok.string)
        except (tokenize.TokenError, IndentationError, SyntaxError):
            pass
        json.dump(comments, sys.stdout)
      PYTHON

      class << self
        def extensions
          [".py"]
        end

        def comment_marker
          "#"
        end

        def extract_comments(source)
          stdout, stderr, status = Open3.capture3("python3", "-c", TOKENIZE_SCRIPT, stdin_data: source)
          raise(Error, "Failed to tokenize Python source: #{stderr}") unless status.success?

          JSON.parse(stdout)
        rescue Errno::ENOENT
          raise(Error, "python3 is required to scan Python source files but was not found on PATH")
        end
      end
    end
  end
end
