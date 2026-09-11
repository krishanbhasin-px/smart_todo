# frozen_string_literal: true

require "test_helper"

module SmartTodo
  module SourceAdapters
    class TomlTest < Minitest::Test
      def test_extracts_a_single_line_comment
        source = <<~TOML
          # TODO(on: date('2024-06-01'), to: 'dev@example.com')
          requires-python = ">=3.10"
        TOML

        assert_equal(["# TODO(on: date('2024-06-01'), to: 'dev@example.com')"], Toml.extract_comments(source))
      end

      def test_extracts_multi_line_continuation_comments
        source = <<~TOML
          # TODO(on: date('2024-06-01'), to: 'dev@example.com')
          #   Raise the floor to 3.11.
          #   Please.
          requires-python = ">=3.10"
        TOML

        assert_equal(
          [
            "# TODO(on: date('2024-06-01'), to: 'dev@example.com')",
            "#   Raise the floor to 3.11.",
            "#   Please.",
          ],
          Toml.extract_comments(source),
        )
      end

      def test_extracts_a_trailing_comment_on_a_key_value_line
        source = <<~TOML
          requires-python = ">=3.10" # TODO(on: date('2024-06-01'), to: 'dev@example.com')
        TOML

        assert_equal(["# TODO(on: date('2024-06-01'), to: 'dev@example.com')"], Toml.extract_comments(source))
      end

      def test_ignores_a_hash_inside_a_basic_string
        source = <<~TOML
          colour = "#not-a-comment"
        TOML

        assert_empty(Toml.extract_comments(source))
      end

      def test_ignores_a_hash_inside_a_literal_string
        source = <<~TOML
          pattern = '#not-a-comment'
        TOML

        assert_empty(Toml.extract_comments(source))
      end

      def test_ignores_a_hash_inside_a_multiline_basic_string
        source = <<~TOML
          script = """
          #!/bin/sh
          # not a comment
          """
          # TODO(on: date('2024-06-01'), to: 'dev@example.com')
        TOML

        assert_equal(["# TODO(on: date('2024-06-01'), to: 'dev@example.com')"], Toml.extract_comments(source))
      end

      def test_ignores_a_hash_inside_a_multiline_literal_string
        source = <<~TOML
          script = '''
          #!/bin/sh
          # not a comment
          '''
          # TODO(on: date('2024-06-01'), to: 'dev@example.com')
        TOML

        assert_equal(["# TODO(on: date('2024-06-01'), to: 'dev@example.com')"], Toml.extract_comments(source))
      end

      def test_ignores_an_escaped_quote_inside_a_basic_string
        source = <<~TOML
          quote = "she said \\"# hi\\" loudly"
          # TODO(on: date('2024-06-01'), to: 'dev@example.com')
        TOML

        assert_equal(["# TODO(on: date('2024-06-01'), to: 'dev@example.com')"], Toml.extract_comments(source))
      end

      # A literal string takes no escapes, so the backslash does not extend it and the
      # closing quote is the next one.
      def test_treats_a_backslash_in_a_literal_string_as_content
        source = <<~TOML
          path = 'C:\\'
          # TODO(on: date('2024-06-01'), to: 'dev@example.com')
        TOML

        assert_equal(["# TODO(on: date('2024-06-01'), to: 'dev@example.com')"], Toml.extract_comments(source))
      end

      # `"""foo""""` is the value `foo"`; the fourth quote belongs to the delimiter. If the
      # scanner left it behind, the unterminated-string fallback would eat the rest of the
      # line and swallow the comment.
      def test_handles_a_quote_immediately_before_a_multiline_delimiter
        source = <<~TOML
          value = """foo"""" # TODO(on: date('2024-06-01'), to: 'dev@example.com')
        TOML

        assert_equal(["# TODO(on: date('2024-06-01'), to: 'dev@example.com')"], Toml.extract_comments(source))
      end

      # An unterminated string must not let the scanner discover a `#` inside it and report
      # it as a live comment.
      def test_ignores_a_hash_inside_an_unterminated_multiline_string
        source = <<~TOML
          value = """
          # not a comment, this string is never closed
        TOML

        assert_empty(Toml.extract_comments(source))
      end

      # The counterpart to the test above: `""` is a legitimate empty string, not the start
      # of an unterminated multi-line one, so it must not swallow the rest of the file.
      def test_still_finds_a_comment_after_an_empty_basic_string
        source = <<~TOML
          value = ""
          # TODO(on: date('2024-06-01'), to: 'dev@example.com')
        TOML

        assert_equal(["# TODO(on: date('2024-06-01'), to: 'dev@example.com')"], Toml.extract_comments(source))
      end

      # A single-line string cannot span lines, so an unterminated one must not swallow a
      # genuine comment further down the file.
      def test_still_finds_a_comment_after_an_unterminated_basic_string
        source = <<~TOML
          value = "oops
          # TODO(on: date('2024-06-01'), to: 'dev@example.com')
        TOML

        assert_equal(["# TODO(on: date('2024-06-01'), to: 'dev@example.com')"], Toml.extract_comments(source))
      end

      def test_returns_utf8_tagged_comments
        source = <<~TOML
          # TODO(on: date('2024-06-01'), to: 'dev@example.com')
          #   Café — rename this.
        TOML

        comments = Toml.extract_comments(source)
        assert_equal(Encoding::UTF_8, comments.last.encoding)
        assert_includes(comments.last, "Café")
      end

      def test_extracts_comments_from_a_file
        Tempfile.create(["pyproject", ".toml"]) do |file|
          file.write(<<~TOML)
            # TODO(on: date('2024-06-01'), to: 'dev@example.com')
            requires-python = ">=3.10"
          TOML
          file.flush

          assert_equal(
            ["# TODO(on: date('2024-06-01'), to: 'dev@example.com')"],
            Toml.extract_comments_from_file(file.path),
          )
        end
      end

      def test_is_registered_for_the_toml_extension
        assert_equal(Toml, SourceAdapters.for_extension(".toml"))
        assert_includes(SourceAdapters.all, Toml)
      end
    end
  end
end
