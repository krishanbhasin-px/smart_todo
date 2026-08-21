# frozen_string_literal: true

require "smart_todo"

module RuboCop
  module Cop
    module SmartTodo
      # A RuboCop used to restrict the usage of regular TODO comments in code.
      # This Cop does not run by default. It should be added to the RuboCop host's configuration file.
      #
      # The rules themselves live in +SmartTodo::Linter+, which is language agnostic and
      # shared with the CLI's +--lint+ mode. This cop only adapts that linter to RuboCop,
      # and therefore only covers Ruby files; use +smart_todo --lint+ for Python and Go.
      #
      # @see https://rubocop.readthedocs.io/en/latest/extensions/#loading-extensions
      class SmartTodoCop < Base
        HELP = ::SmartTodo::Linter::HELP
        MSG = ::SmartTodo::Linter::MSG

        # @param processed_source [RuboCop::ProcessedSource]
        # @return [void]
        def on_new_investigation
          processed_source.comments.each do |comment|
            next unless (message = linter.check(comment.text))

            add_offense(comment, message: message)
          end
        end

        private

        # @return [SmartTodo::Linter]
        def linter
          @linter ||= ::SmartTodo::Linter.new(marker: "#")
        end
      end
    end
  end
end
