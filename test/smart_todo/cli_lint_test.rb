# frozen_string_literal: true

require "test_helper"
require "open3"
require "tmpdir"

module SmartTodo
  class CLILintTest < Minitest::Test
    def test_reports_regular_todos_across_ruby_python_and_go
      Dir.mktmpdir do |dir|
        File.write(File.join(dir, "hello.rb"), "# TODO: fix the ruby\n")
        File.write(File.join(dir, "hello.py"), "# TODO: fix the python\n")
        File.write(File.join(dir, "hello.go"), "// TODO: fix the go\n")

        cli = CLI.new
        output, = capture_io do
          assert_equal(1, cli.run([dir, "--lint"]))
        end

        assert_includes(output, "hello.rb: Don't write regular TODO comments")
        assert_includes(output, "hello.py: Don't write regular TODO comments")
        assert_includes(output, "hello.go: Don't write regular TODO comments")
      end
    end

    def test_is_silent_and_succeeds_when_every_todo_is_a_smart_todo
      Dir.mktmpdir do |dir|
        File.write(File.join(dir, "hello.rb"), "# TODO(on: date('2019-08-04'), to: 'dev@example.com')\n")
        File.write(File.join(dir, "hello.py"), "# TODO(on: date('2019-08-04'), to: 'dev@example.com')\n")
        File.write(File.join(dir, "hello.go"), "// TODO(on: date('2019-08-04'), to: 'dev@example.com')\n")

        cli = CLI.new
        output, = capture_io do
          assert_equal(0, cli.run([dir, "--lint"]))
        end

        assert_equal("", output)
      end
    end

    def test_reports_invalid_smart_todo_metadata_in_a_python_file
      Dir.mktmpdir do |dir|
        File.write(File.join(dir, "bad.py"), "# TODO(on: data('2019-08-04'), to: 'dev@example.com')\n")

        cli = CLI.new
        output, = capture_io do
          assert_equal(1, cli.run([dir, "--lint"]))
        end

        assert_includes(output, "bad.py: Invalid event method(s): data.")
      end
    end

    def test_records_an_error_when_python_cannot_be_scanned
      Dir.mktmpdir do |dir|
        File.write(File.join(dir, "hello.py"), "# TODO: fix the python\n")

        cli = CLI.new
        capture_io do
          Open3.stub(:capture3, ->(*) { raise(Errno::ENOENT) }) do
            assert_equal(1, cli.run([dir, "--lint"]))
          end
        end

        refute_empty(cli.instance_variable_get(:@errors))
      end
    end
  end
end
