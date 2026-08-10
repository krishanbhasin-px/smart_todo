# frozen_string_literal: true

module SmartTodo
  module SourceAdapters
    # The original adapter: scans Ruby source using the same Prism parser that later
    # parses each TODO's metadata expression.
    class Ruby < Base
      class << self
        def extensions
          [".rb"]
        end

        def comment_marker
          "#"
        end

        def extract_comments(source)
          comments =
            if Prism.respond_to?(:parse_comments)
              Prism.parse_comments(source)
            else
              Prism.parse(source).comments
            end

          comments.select { |comment| inline?(comment) }.map { |comment| comment.location.slice }
        end

        def extract_comments_from_file(filepath)
          comments =
            if Prism.respond_to?(:parse_file_comments)
              Prism.parse_file_comments(filepath)
            else
              Prism.parse_file(filepath).comments
            end

          comments.select { |comment| inline?(comment) }.map { |comment| comment.location.slice }
        end

        private

        # Excludes =begin/=end embedded doc comments, which have no equivalent smart
        # TODO syntax.
        def inline?(comment)
          if defined?(Prism::InlineComment)
            comment.is_a?(Prism::InlineComment)
          else
            comment.type == :inline
          end
        end
      end
    end
  end
end
