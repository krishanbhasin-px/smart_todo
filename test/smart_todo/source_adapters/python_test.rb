# frozen_string_literal: true

require "test_helper"

module SmartTodo
  module SourceAdapters
    class PythonTest < Minitest::Test
      def test_extracts_a_single_comment
        source = <<~PYTHON
          # TODO(on: date('2024-06-01'), to: 'dev@example.com')
          def hello():
              pass
        PYTHON

        comments = Python.extract_comments(source)
        assert_equal(["# TODO(on: date('2024-06-01'), to: 'dev@example.com')"], comments)
      end

      def test_extracts_multi_line_continuation_comments
        source = <<~PYTHON
          # TODO(on: date('2024-06-01'), to: 'dev@example.com')
          #   Revisit the way we say hello.
          #   Please.
          def hello():
              pass
        PYTHON

        comments = Python.extract_comments(source)
        assert_equal(
          [
            "# TODO(on: date('2024-06-01'), to: 'dev@example.com')",
            "#   Revisit the way we say hello.",
            "#   Please.",
          ],
          comments,
        )
      end

      def test_ignores_hash_inside_a_string_literal
        source = <<~PYTHON
          x = "# not a comment"
        PYTHON

        assert_empty(Python.extract_comments(source))
      end

      def test_ignores_hash_inside_a_triple_quoted_string
        source = <<~PYTHON
          x = """
          # not a comment either
          """
        PYTHON

        assert_empty(Python.extract_comments(source))
      end

      def test_ignores_hash_inside_an_f_string
        source = <<~'PYTHON'
          name = "world"
          x = f"hello {name} # not a comment"
        PYTHON

        assert_empty(Python.extract_comments(source))
      end

      def test_extracts_trailing_comments
        source = <<~PYTHON
          x = 1  # TODO(on: date('2024-06-01'), to: 'dev@example.com')
        PYTHON

        comments = Python.extract_comments(source)
        assert_equal(["# TODO(on: date('2024-06-01'), to: 'dev@example.com')"], comments)
      end

      def test_tolerant_of_trailing_syntax_errors
        source = <<~PYTHON
          # TODO(on: date('2024-06-01'), to: 'dev@example.com')
          x = "unterminated
        PYTHON

        comments = Python.extract_comments(source)
        assert_equal(["# TODO(on: date('2024-06-01'), to: 'dev@example.com')"], comments)
      end

      def test_end_to_end_through_comment_parser
        Tempfile.open(["file", ".py"]) do |file|
          file.write(<<~PYTHON)
            # TODO(on: date('2024-06-01'), to: 'dev@example.com')
            #   Remove this once done.
            def hello():
                pass
          PYTHON
          file.rewind

          todos = CommentParser.parse(File.read(file.path), adapter: Python)
          assert_equal(1, todos.size)
          assert_equal(:date, todos[0].events[0].method_name)
          assert_equal(["dev@example.com"], todos[0].assignees)
          assert_equal("Remove this once done.\n", todos[0].comment)
        end
      end
    end
  end
end
