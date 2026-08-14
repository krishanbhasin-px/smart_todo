# frozen_string_literal: true

require "test_helper"

module SmartTodo
  class CommentParserTest < Minitest::Test
    def test_parse_one_todo_with_single_line_comment
      ruby_code = <<~RUBY
        # TODO(on: date('2019-08-04'), to: 'john@example.com')
        #   Remove this code once done
        def hello
        end
      RUBY

      todo = CommentParser.parse(ruby_code)
      assert_equal(1, todo.size)
      assert_equal("Remove this code once done\n", todo[0].comment)
    end

    def test_parse_multiple_todo_with_single_line_comment
      ruby_code = <<~RUBY
        # TODO(on: date('2019-08-04'), to: 'john@example.com')
        #   Remove this code once done
        def hello
        end

        # TODO(on: date('2019-08-04'), to: 'john@example.com')
        #   Remove this code once done
        def bar
        end
      RUBY

      todo = CommentParser.parse(ruby_code)
      assert_equal(2, todo.size)
      assert_equal("Remove this code once done\n", todo[0].comment)
      assert_equal("Remove this code once done\n", todo[1].comment)
    end

    def test_parse_one_todo_with_multi_line_comment
      ruby_code = <<~RUBY
        # TODO(on: date('2019-08-04'), to: 'john@example.com')
        #   Remove this code once done
        #   This is important
        #   Please don't disappoint me
        def hello
        end
      RUBY

      todo = CommentParser.parse(ruby_code)
      assert_equal(1, todo.size)
      assert_equal(<<~EOM, todo[0].comment)
        Remove this code once done
        This is important
        Please don't disappoint me
      EOM
    end

    def test_parse_multiple_todo_with_multi_line_comment
      ruby_code = <<~RUBY
        # TODO(on: date('2019-08-04'), to: 'john@example.com')
        #   Remove this code once done
        #   This is important
        #   Please don't disappoint me
        def hello
        end

        # TODO(on: date('2019-08-04'), to: 'john@example.com')
        #   Hello World
        #   Good Bye!
        def bar
        end
      RUBY

      todo = CommentParser.parse(ruby_code)
      assert_equal(2, todo.size)
      assert_equal(<<~EOM, todo[0].comment)
        Remove this code once done
        This is important
        Please don't disappoint me
      EOM
      assert_equal(<<~EOM, todo[1].comment)
        Hello World
        Good Bye!
      EOM
    end

    def test_parse_no_todo
      ruby_code = <<~RUBY
        # This is a regular comment
        def hello
        end
      RUBY

      todo = CommentParser.parse(ruby_code)
      assert_empty(todo)
    end

    def test_parse_todo_with_no_comment
      ruby_code = <<~RUBY
        # TODO(on: date('2019-08-04'), to: 'john@example.com')
        def hello
        end
      RUBY

      todo = CommentParser.parse(ruby_code)
      assert_equal(1, todo.size)
      assert_equal("", todo[0].comment)
    end

    def test_parse_todo_with_unindented_comment
      ruby_code = <<~RUBY
        # TODO(on: date('2019-08-04'), to: 'john@example.com')
        # Oups comment is not indented to the TODO
        def hello
        end
      RUBY

      todo = CommentParser.parse(ruby_code)
      assert_equal(1, todo.size)
      assert_equal("", todo[0].comment)
    end

    def test_parse_todo_with_weird_comment_indentation
      ruby_code = <<~RUBY
        # TODO(on: date('2019-08-04'), to: 'john@example.com')
        #bla
      RUBY

      todo = CommentParser.parse(ruby_code)
      assert_equal(1, todo.size)
      assert_equal("", todo[0].comment)
    end

    def test_parse_todo_with_nothing_else
      ruby_code = <<~RUBY
        # TODO(on: date('2019-08-04'), to: 'john@example.com')
        #   The rest of the file is completely empty
      RUBY

      todo = CommentParser.parse(ruby_code)
      assert_equal(1, todo.size)
      assert_equal("The rest of the file is completely empty\n", todo[0].comment)
    end

    def test_parse_no_comment_at_all
      ruby_code = <<~RUBY
        def hello
        end
      RUBY

      todo = CommentParser.parse(ruby_code)
      assert_empty(todo)
    end

    def test_parse_todo_and_creates_metadata
      ruby_code = <<~RUBY
        # TODO(on: date('2019-08-04'), to: 'john@example.com')
        def hello
        end
      RUBY

      todo = CommentParser.parse(ruby_code)
      assert_equal(:date, todo[0].events[0].method_name)
      assert_equal(["john@example.com"], todo[0].assignees)
    end

    def test_parse_fixme_and_creates_metadata
      ruby_code = <<~RUBY
        # FIXME(on: date('2019-08-04'), to: 'john@example.com')
        def hello
        end
      RUBY

      todo = CommentParser.parse(ruby_code)
      assert_equal(:date, todo[0].events[0].method_name)
      assert_equal(["john@example.com"], todo[0].assignees)
    end

    def test_parse_optimize_and_creates_metadata
      ruby_code = <<~RUBY
        # OPTIMIZE(on: date('2019-08-04'), to: 'john@example.com')
        def hello
        end
      RUBY

      todo = CommentParser.parse(ruby_code)
      assert_equal(:date, todo[0].events[0].method_name)
      assert_equal(["john@example.com"], todo[0].assignees)
    end

    def test_go_block_comment_does_not_corrupt_a_preceding_todo
      # A Go block comment is a single multi-line +comments+ entry. Before the `\A`
      # anchor fix, `^` matched at every internal line start, so the `//   inner line`
      # inside this block comment was misdetected as a tag/continuation line and
      # corrupted the preceding real TODO's comment with leaked raw source.
      comments = [
        "// TODO(on: date('2019-07-01'), to: 'me@example.com')",
        "//   Remove this once done.",
        "/* stray block\n//   inner line\nend of block */",
      ]

      parser = CommentParser.new(adapter: SourceAdapters::Go)
      parser.parse_extracted(comments, "-e")
      todos = parser.todos

      assert_equal(1, todos.size)
      assert_equal("Remove this once done.\n", todos[0].comment)
    end
  end
end
