# frozen_string_literal: true

module SmartTodo
  module SourceAdapters
    # @abstract Subclasses represent a host language that SmartTodo can scan for TODO
    #   comments. Only comment *extraction* is language-specific: once a comment's raw
    #   text has been pulled out of the source file, the smart TODO metadata inside it
    #   (+on: date(...), to: '...'+) is always parsed as a small Ruby expression via
    #   Prism, regardless of which adapter found it and which language the host file is
    #   written in.
    class Base
      class << self
        # @return [Array<String>] file extensions (including the leading dot) this
        #   adapter handles, e.g. +[".rb"]+.
        def extensions
          raise(NotImplementedError, "subclass responsibility")
        end

        # @return [String] the comment marker prefixing a smart TODO line, e.g. "#" or "//".
        def comment_marker
          raise(NotImplementedError, "subclass responsibility")
        end

        # @param source [String]
        # @return [Array<String>] the literal text of every comment in +source+, in
        #   source order. Each entry starts with +comment_marker+. Implementations must
        #   ignore any occurrence of the marker inside a string/rune/byte literal.
        def extract_comments(source)
          raise(NotImplementedError, "subclass responsibility")
        end

        # @param filepath [String]
        # @return [Array<String>]
        def extract_comments_from_file(filepath)
          extract_comments(File.read(filepath))
        end

        # @return [String] a glob pattern (relative to a directory) matching this
        #   language's source files.
        def glob_pattern
          "**/*#{extensions.first}"
        end
      end
    end
  end
end
