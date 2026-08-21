# frozen_string_literal: true

require "date"

module SmartTodo
  # Decides whether a single comment is an acceptable smart TODO and, when it isn't,
  # explains why.
  #
  # Language-agnostic: the host language only determines the +marker+ prefixing a
  # comment ("#" for Ruby and Python, "//" for Go). The metadata inside a smart TODO
  # is always a Ruby expression parsed by +Todo+, whichever language the comment was
  # found in.
  class Linter
    HELP = "For more info please look at https://github.com/Shopify/smart_todo/wiki/Syntax"
    MSG = "Don't write regular TODO comments. Write SmartTodo compatible syntax comments. #{HELP}"
    INVESTIGATED_TAGS = CommentParser::SUPPORTED_TAGS + CommentParser::SUPPORTED_TAGS.map(&:downcase)

    # @param marker [String] the host language's comment marker, e.g. "#" or "//".
    def initialize(marker: "#")
      @marker = marker
      @todo_pattern = /^#{Regexp.escape(marker)}\s@?(#{INVESTIGATED_TAGS.join("|")})\b/
    end

    # @param comment [String] one comment's literal text, including its marker.
    # @return [String, nil] a violation message, or +nil+ when the comment is not a
    #   TODO at all or is a valid smart TODO.
    def check(comment)
      return unless (match = @todo_pattern.match(comment))
      return MSG if match[1] != match[1].upcase

      metadata = Todo.new(comment, marker: @marker)

      if metadata.errors.any?
        "Invalid TODO format: #{metadata.errors.join(", ")}. #{HELP}"
      elsif !smart_todo?(metadata)
        MSG
      elsif invalid_assignees(metadata.assignees).any?
        "Invalid event assignee. This method only accepts strings. #{HELP}"
      elsif (invalid_events = validate_events(metadata.events)).any?
        "#{invalid_events.join(". ")}. #{HELP}"
      end
    end

    private

    # @param metadata [Todo]
    # @return [true, false]
    def smart_todo?(metadata)
      metadata.events.any? &&
        metadata.events.all? { |event| event.is_a?(Todo::CallNode) } &&
        metadata.assignees.any?
    end

    # @param assignees [Array]
    # @return [Array]
    def invalid_assignees(assignees)
      assignees.reject { |assignee| assignee.is_a?(String) }
    end

    # @param events [Array<Todo::CallNode>]
    # @return [Array<String>]
    def validate_events(events)
      invalid_methods = events.map(&:method_name).reject { |method| Events.method_defined?(method) }
      return ["Invalid event method(s): #{invalid_methods.join(", ")}"] if invalid_methods.any?

      events.map do |event|
        send(validate_method(event.method_name), event.arguments)
      end.compact
    end

    # @param event_type [Symbol]
    # @return [String]
    def validate_method(event_type)
      "validate_#{event_type}_args"
    end

    # @param args [Array]
    # @return [String, nil] Returns error message if date is invalid, nil if valid
    def validate_date_args(args)
      date = args.first
      Date.parse(date)
      nil
    rescue ArgumentError, TypeError
      "Invalid date format: #{date}"
    end

    # @param args [Array]
    # @return [String, nil] Returns error message if arguments are invalid, nil if valid
    def validate_issue_close_args(args)
      validate_fixed_arity_args(args, 3, "issue_close", ["organization", "repo", "issue_number"])
    end

    # @param args [Array]
    # @return [String, nil] Returns error message if arguments are invalid, nil if valid
    def validate_pull_request_close_args(args)
      validate_fixed_arity_args(args, 3, "pull_request_close", ["organization", "repo", "pr_number"])
    end

    # @param args [Array]
    # @return [String, nil] Returns error message if arguments are invalid, nil if valid
    def validate_gem_release_args(args)
      validate_gem_args(args, "gem_release")
    end

    # @param args [Array]
    # @return [String, nil] Returns error message if arguments are invalid, nil if valid
    def validate_gem_bump_args(args)
      validate_gem_args(args, "gem_bump")
    end

    # @param args [Array]
    # @return [String, nil] Returns error message if arguments are invalid, nil if valid
    def validate_ruby_version_args(args)
      if args.empty?
        "Invalid ruby_version event: Expected at least 1 argument (version requirement), got 0"
      elsif !args.all? { |arg| arg.is_a?(String) }
        "Invalid ruby_version event: Version requirements must be strings"
      end
    end

    # Helper method for validating fixed arity events
    def validate_fixed_arity_args(args, expected_count, event_name, arg_names)
      if args.size != expected_count
        message = "Invalid #{event_name} event: Expected #{expected_count} arguments "
        message += "(#{arg_names.join(", ")}), got #{args.size}"
        message
      elsif !args.all? { |arg| arg.is_a?(String) }
        "Invalid #{event_name} event: Arguments must be strings"
      end
    end

    # Helper method for validating gem-related events
    def validate_gem_args(args, event_name)
      if args.empty?
        "Invalid #{event_name} event: Expected at least 1 argument (gem_name), got 0"
      elsif !args[0].is_a?(String)
        "Invalid #{event_name} event: First argument (gem_name) must be a string"
      elsif args.size > 1 && !args[1..].all? { |arg| arg.is_a?(String) }
        "Invalid #{event_name} event: Version requirements must be strings"
      end
    end
  end
end
