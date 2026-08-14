# frozen_string_literal: true

require "test_helper"
require "open3"
require "tmpdir"

module SmartTodo
  class CLIMultiLanguageTest < Minitest::Test
    def test_scans_ruby_and_python_files_in_the_same_directory
      Dir.mktmpdir do |dir|
        File.write(File.join(dir, "hello.rb"), <<~RUBY)
          # TODO(on: date('2015-03-01'), to: 'ruby@example.com')
          #   Ruby TODO.
          def hello
          end
        RUBY

        File.write(File.join(dir, "hello.py"), <<~PYTHON)
          # TODO(on: date('2015-03-01'), to: 'python@example.com')
          #   Python TODO.
          def hello():
              pass
        PYTHON

        cli = CLI.new
        output, = capture_io do
          assert_equal(0, cli.run([dir, "--slack_token", "123", "--fallback_channel", "#general"]))
        end

        assert_includes(output, "hello.rb")
        assert_includes(output, "Ruby TODO.")
        assert_includes(output, "hello.py")
        assert_includes(output, "Python TODO.")
      end
    end

    def test_falls_back_to_ruby_for_an_explicit_file_with_an_unrecognized_extension
      Dir.mktmpdir do |dir|
        path = File.join(dir, "Rakefile")
        File.write(path, <<~RUBY)
          # TODO(on: date('2015-03-01'), to: 'ruby@example.com')
          #   Rakefile TODO.
          task :default
        RUBY

        cli = CLI.new
        output, = capture_io do
          assert_equal(0, cli.run([path, "--slack_token", "123", "--fallback_channel", "#general"]))
        end

        assert_includes(output, "Rakefile")
        assert_includes(output, "Rakefile TODO.")
      end
    end

    def test_continues_scanning_other_files_when_python_is_unavailable
      Dir.mktmpdir do |dir|
        File.write(File.join(dir, "hello.rb"), <<~RUBY)
          # TODO(on: date('2015-03-01'), to: 'ruby@example.com')
          #   Ruby TODO.
          def hello
          end
        RUBY

        File.write(File.join(dir, "hello.py"), <<~PYTHON)
          # TODO(on: date('2015-03-01'), to: 'python@example.com')
          #   Python TODO.
          def hello():
              pass
        PYTHON

        cli = CLI.new
        output, = capture_io do
          Open3.stub(:capture3, ->(*) { raise(Errno::ENOENT) }) do
            assert_equal(1, cli.run([dir, "--slack_token", "123", "--fallback_channel", "#general"]))
          end
        end

        assert_includes(output, "hello.rb")
        assert_includes(output, "Ruby TODO.")
        refute_includes(output, "Python TODO.")
        refute_empty(cli.instance_variable_get(:@errors))
      end
    end
  end
end
