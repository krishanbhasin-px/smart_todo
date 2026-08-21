# frozen_string_literal: true

require "optionparser"
require "etc"

module SmartTodo
  # This class is the entrypoint of the SmartTodo library and is responsible
  # to retrieve the command line options as well as iterating over each files/directories
  # to run the +CommentParser+ on.
  class CLI
    def initialize(dispatcher = nil)
      @options = {}
      @errors = []
      @dispatcher = dispatcher
    end

    # @param args [Array<String>]
    def run(args = ARGV)
      paths = define_options.parse!(args)
      validate_options!

      paths << "." if paths.empty?

      filepaths = paths.flat_map { |path| normalize_path(path) }
      comment_parsers = Hash.new { |hash, adapter| hash[adapter] = CommentParser.new(adapter: adapter) }

      filepaths.group_by { |filepath| adapter_for(filepath) }.each do |adapter, adapter_filepaths|
        scan_files(adapter, adapter_filepaths, comment_parsers[adapter])
      end

      todos = comment_parsers.each_value.flat_map(&:todos)

      process_dispatches(process_todos(todos))

      if @errors.empty?
        0
      else
        $stderr.puts "There were errors while checking for TODOs:\n"

        @errors.each do |error|
          $stderr.puts error
        end

        1
      end
    end

    # @raise [ArgumentError] In case an option needed by a dispatcher wasn't provided.
    #
    # @return [void]
    def validate_options!
      dispatcher.validate_options!(@options)
    end

    # @return [OptionParser] an instance of OptionParser
    def define_options
      OptionParser.new do |opts|
        opts.banner = "Usage: smart_todo [options] file_or_path1 file_or_path2 ..."
        opts.on("--slack_token TOKEN") do |token|
          @options[:slack_token] = token
        end
        opts.on("--fallback_channel CHANNEL") do |channel|
          @options[:fallback_channel] = channel
        end
        opts.on("--dispatcher DISPATCHER") do |dispatcher|
          @options[:dispatcher] = dispatcher
        end
        opts.on("--repo [REPO]", "Repository name to include in notifications") do |repo|
          @options[:repo] = repo || File.basename(Dir.pwd)
        end
      end
    end

    # @return [Class] a Dispatchers::Base subclass
    def dispatcher
      @dispatcher ||= Dispatchers::Base.class_for(@options[:dispatcher])
    end

    # @param path [String] a path to a file or directory
    # @return [Array<String>] all the files the parser should run on
    def normalize_path(path)
      if File.file?(path)
        [path]
      else
        extensions = SourceAdapters.all.flat_map(&:extensions).join(",")
        Dir["#{path}/**/*{#{extensions}}"].sort
      end
    end

    # @param filepath [String]
    # @return [Class] a SourceAdapters::Base subclass
    def adapter_for(filepath)
      SourceAdapters.for_extension(File.extname(filepath)) || SourceAdapters::Ruby
    end

    def process_todos(todos)
      events = Events.new
      dispatches = []

      todos.each do |todo|
        event_message = nil
        event_met = todo.events.find do |event|
          event_message = events.public_send(event.method_name, *event.arguments)
        rescue => e
          message = "Error while parsing #{todo.filepath} on event `#{event.method_name}` " \
            "with arguments #{event.arguments.map(&:inspect)}: " \
            "#{e.message}"

          @errors << message

          nil
        end

        @errors.concat(todo.errors)

        next unless event_met

        event_message = append_context_if_applicable(event_message, todo, event_met, events)

        dispatches << [event_message, todo]
      end

      dispatches
    end

    private

    # @param adapter [Class] a SourceAdapters::Base subclass
    # @param filepaths [Array<String>] every file to scan with this adapter
    # @param parser [CommentParser]
    def scan_files(adapter, filepaths, parser)
      if adapter.respond_to?(:extract_comments_from_files)
        begin
          comments_by_file = adapter.extract_comments_from_files(filepaths)

          filepaths.each do |filepath|
            parser.parse_extracted(comments_by_file.fetch(filepath), filepath)

            $stdout.print(".")
            $stdout.flush
          end

          return
        rescue
          # Batching is only an optimization: fall back to scanning each file
          # individually below. Whether that fallback succeeds or not is what
          # determines the exit code, so no error is recorded here — the
          # per-file loop below reports only failures that persist.
        end
      end

      filepaths.each do |filepath|
        begin
          parser.parse_file(filepath) unless parser.todos.any? { |todo| todo.filepath == filepath }
        rescue => e
          @errors << "Error while scanning #{filepath}: #{e.message}"
          next
        end

        $stdout.print(".")
        $stdout.flush
      end
    end

    # @param event_message [String] the original event message
    # @param todo [Todo] the todo object that may contain context
    # @param event [Event] the event that was met
    # @param events [Events] the events instance for fetching issue context
    # @return [String] the event message, potentially with context appended
    def append_context_if_applicable(event_message, todo, event, events)
      return event_message unless should_apply_context?(todo, event)

      org, repo, issue_number = todo.context.arguments
      context_message = events.issue_context(org, repo, issue_number)

      context_message ? "#{event_message}\n\n#{context_message}" : event_message
    end

    # @param todo [Todo] the todo object to check for context
    # @param event [Event] the event to check
    # @return [Boolean] true if context should be applied, false otherwise
    def should_apply_context?(todo, event)
      !!todo.context
    end

    def process_dispatches(dispatches)
      queue = Queue.new
      dispatches.each { |dispatch| queue << dispatch }

      thread_count = Etc.nprocessors
      thread_count.times { queue << nil }

      threads =
        thread_count.times.map do
          Thread.new do
            Thread.current.abort_on_exception = true

            loop do
              dispatch = queue.pop
              break if dispatch.nil?

              (event_message, todo) = dispatch
              dispatcher.new(event_message, todo, todo.filepath, @options).dispatch
            end
          end
        end

      threads.each(&:join)
    end
  end
end
