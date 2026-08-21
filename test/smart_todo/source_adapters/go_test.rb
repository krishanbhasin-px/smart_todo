# frozen_string_literal: true

require "test_helper"

module SmartTodo
  module SourceAdapters
    class GoTest < Minitest::Test
      def test_extracts_a_single_line_comment
        source = <<~GO
          // TODO(on: date('2024-06-01'), to: 'dev@example.com')
          func hello() {}
        GO

        comments = Go.extract_comments(source)
        assert_equal(["// TODO(on: date('2024-06-01'), to: 'dev@example.com')"], comments)
      end

      def test_extracts_multi_line_continuation_comments
        source = <<~GO
          // TODO(on: date('2024-06-01'), to: 'dev@example.com')
          //   Revisit the way we say hello.
          //   Please.
          func hello() {}
        GO

        comments = Go.extract_comments(source)
        assert_equal(
          [
            "// TODO(on: date('2024-06-01'), to: 'dev@example.com')",
            "//   Revisit the way we say hello.",
            "//   Please.",
          ],
          comments,
        )
      end

      def test_extracts_block_comments
        source = <<~GO
          /* a block comment */
          func hello() {}
        GO

        assert_equal(["/* a block comment */"], Go.extract_comments(source))
      end

      def test_ignores_slashes_inside_an_interpreted_string
        source = <<~GO
          s := "not a // comment or /* block */ inside a string"
        GO

        assert_empty(Go.extract_comments(source))
      end

      def test_ignores_slashes_inside_a_raw_string
        source = <<~GO
          s := `not a // comment or /* block */ inside a raw string`
        GO

        assert_empty(Go.extract_comments(source))
      end

      def test_ignores_slashes_inside_a_rune_literal
        source = <<~GO
          r := '/'
          // TODO(on: date('2024-06-01'), to: 'dev@example.com')
        GO

        assert_equal(["// TODO(on: date('2024-06-01'), to: 'dev@example.com')"], Go.extract_comments(source))
      end

      def test_extracts_trailing_comments
        source = <<~GO
          x := 1 // TODO(on: date('2024-06-01'), to: 'dev@example.com')
        GO

        assert_equal(["// TODO(on: date('2024-06-01'), to: 'dev@example.com')"], Go.extract_comments(source))
      end

      def test_end_to_end_through_comment_parser
        todos = CommentParser.parse(<<~GO, adapter: Go)
          // TODO(on: date('2024-06-01'), to: 'dev@example.com')
          //   Remove this once done.
          func hello() {}
        GO

        assert_equal(1, todos.size)
        assert_equal(:date, todos[0].events[0].method_name)
        assert_equal(["dev@example.com"], todos[0].assignees)
        assert_equal("Remove this once done.\n", todos[0].comment)
      end

      def test_strips_trailing_carriage_return_on_crlf_source
        source = "// TODO(on: date('2024-06-01'), to: 'dev@example.com')\r\n//   Remove this.\r\n"

        comments = Go.extract_comments(source)
        assert_equal(
          ["// TODO(on: date('2024-06-01'), to: 'dev@example.com')", "//   Remove this."],
          comments,
        )
      end

      def test_does_not_treat_a_slash_inside_an_unterminated_string_as_a_comment
        source = <<~GO
          s := "unterminated string with a // TODO(on: date('2024-06-01'), to: 'dev@example.com')
        GO

        assert_empty(Go.extract_comments(source))
      end

      def test_does_not_treat_a_slash_inside_an_unterminated_rune_literal_as_a_comment
        source = <<~GO
          r := '// this looks like a comment but is not
        GO

        assert_empty(Go.extract_comments(source))
      end

      def test_does_not_raise_on_invalid_utf8_bytes
        source = "s := \"\xFF\xFE\"\n// TODO(on: date('2024-06-01'), to: 'dev@example.com')\n"
        refute_predicate(source, :valid_encoding?)

        comments = Go.extract_comments(source)
        assert_equal(["// TODO(on: date('2024-06-01'), to: 'dev@example.com')"], comments)
      end
    end
  end
end
