# frozen_string_literal: true

module SmartTodo
  module SourceAdapters
    class << self
      # @return [Array<Class>] every registered adapter.
      def all
        [Ruby, Python, Go]
      end

      # @param extension [String] a file extension including the leading dot, e.g. ".py"
      # @return [Class, nil] the adapter that handles this extension, if any.
      def for_extension(extension)
        case extension
        when ".rb" then Ruby
        when ".py" then Python
        when ".go" then Go
        end
      end
    end
  end
end
