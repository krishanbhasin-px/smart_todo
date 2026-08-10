# frozen_string_literal: true

module SmartTodo
  # Groups a source file's comments into +Todo+ objects. Comment extraction is
  # delegated to a +SourceAdapters+ class (Ruby by default); everything past that —
  # tag detection, continuation-line grouping, metadata parsing — is language agnostic.
  class CommentParser
    SUPPORTED_TAGS = ["TODO", "FIXME", "OPTIMIZE"].freeze

    attr_reader :todos

    # @param adapter [Class] a SmartTodo::SourceAdapters::Base subclass
    def initialize(adapter: SourceAdapters::Ruby)
      @adapter = adapter
      @todos = []
      @tag_pattern = /^#{Regexp.escape(adapter.comment_marker)}\s(#{SUPPORTED_TAGS.join("|")})\(/
      @indent_pattern = /^#{Regexp.escape(adapter.comment_marker)}(\s*)/
    end

    def parse(source, filepath = "-e")
      parse_comments(@adapter.extract_comments(source), filepath)
    end

    def parse_file(filepath)
      parse_comments(@adapter.extract_comments_from_file(filepath), filepath)
    end

    class << self
      def parse(source, adapter: SourceAdapters::Ruby)
        parser = new(adapter: adapter)
        parser.parse(source)
        parser.todos
      end
    end

    private

    def parse_comments(comments, filepath)
      current_todo = nil
      marker_length = @adapter.comment_marker.length

      comments.each do |source|
        if source.match?(@tag_pattern)
          todos << current_todo if current_todo
          current_todo = Todo.new(source, filepath, marker: @adapter.comment_marker)
        elsif current_todo && (indent = source[@indent_pattern, 1]&.length) && (indent - current_todo.indent == 2)
          current_todo << "#{source[(indent + marker_length)..]}\n"
        else
          todos << current_todo if current_todo
          current_todo = nil
        end
      end

      todos << current_todo if current_todo
    end
  end
end
