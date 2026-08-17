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

      # `-I` (isolated mode) keeps the scanned repository's directory off Python's import
      # path. Without it, a scanned tree containing e.g. `tokenize.py` or `json.py` would
      # shadow the stdlib modules this script imports, letting arbitrary project code
      # execute during comment scanning.

      # Reads the source to scan from stdin (as bytes, so tokenize can honor a PEP 263
      # encoding declaration) and prints a JSON array of raw comment strings to stdout.
      # Tolerant of trailing syntax errors (e.g. an unterminated string at EOF), matching
      # Prism's leniency for the Ruby adapter: whatever was tokenized before the error is
      # still returned.
      # `tokenize.detect_encoding` is called separately, outside the tolerant try/except
      # below: it raises SyntaxError *before* yielding any tokens when the source's first
      # two lines contain a byte invalid for the assumed encoding (no PEP 263 cookie). Left
      # unguarded, that SyntaxError exits the script non-zero with a message on stderr,
      # which surfaces through +extract_comments+'s error handling instead of silently
      # dropping every comment in the file.
      TOKENIZE_SCRIPT = <<~PYTHON
        import io
        import json
        import sys
        import tokenize

        source = sys.stdin.buffer.read()

        tokenize.detect_encoding(io.BytesIO(source).readline)

        comments = []
        try:
            for tok in tokenize.tokenize(io.BytesIO(source).readline):
                if tok.type == tokenize.COMMENT:
                    comments.append(tok.string)
        except (tokenize.TokenError, IndentationError, SyntaxError):
            pass
        json.dump(comments, sys.stdout)
      PYTHON

      # Batched form of +TOKENIZE_SCRIPT+: reads and tokenizes every path in argv within a
      # single python3 process, to avoid paying interpreter-boot cost once per file.
      BATCH_TOKENIZE_SCRIPT = <<~PYTHON
        import io
        import json
        import sys
        import tokenize

        results = {}

        for filepath in sys.argv[1:]:
            try:
                with open(filepath, "rb") as f:
                    source = f.read()

                tokenize.detect_encoding(io.BytesIO(source).readline)

                comments = []
                try:
                    for tok in tokenize.tokenize(io.BytesIO(source).readline):
                        if tok.type == tokenize.COMMENT:
                            comments.append(tok.string)
                except (tokenize.TokenError, IndentationError, SyntaxError):
                    pass

                results[filepath] = {"comments": comments}
            except (OSError, SyntaxError) as e:
                results[filepath] = {"error": str(e)}

        json.dump(results, sys.stdout)
      PYTHON

      class << self
        def extensions
          [".py"]
        end

        def comment_marker
          "#"
        end

        def extract_comments(source)
          stdout, stderr, status = Open3.capture3("python3", "-I", "-c", TOKENIZE_SCRIPT, stdin_data: source)
          raise(Error, "Failed to tokenize Python source: #{stderr}") unless status.success?

          JSON.parse(stdout)
        rescue Errno::ENOENT
          raise(Error, "python3 is required to scan Python source files but was not found on PATH")
        end

        # @param filepaths [Array<String>]
        # @return [Hash{String => Array<String>}] each filepath mapped to its comments.
        # @raise [Error] if the batch process fails, or if any individual file fails to
        #   tokenize. Callers should fall back to per-file +extract_comments_from_file+ in
        #   that case.
        def extract_comments_from_files(filepaths)
          stdout, stderr, status = Open3.capture3("python3", "-I", "-c", BATCH_TOKENIZE_SCRIPT, *filepaths)
          raise(Error, "Failed to tokenize Python source: #{stderr}") unless status.success?

          results = JSON.parse(stdout)

          filepaths.each_with_object({}) do |filepath, comments_by_file|
            result = results.fetch(filepath)
            raise(Error, "Failed to tokenize #{filepath}: #{result["error"]}") if result["error"]

            comments_by_file[filepath] = result["comments"]
          end
        rescue Errno::ENOENT
          raise(Error, "python3 is required to scan Python source files but was not found on PATH")
        end
      end
    end
  end
end
