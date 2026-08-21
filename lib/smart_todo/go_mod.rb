# frozen_string_literal: true

module SmartTodo
  # Resolves a Go module path to its locally-required version by hand-parsing
  # `go.mod`'s `require` and `replace` directives. No dependency on a Go
  # toolchain, mirroring `SourceAdapters::Go`'s own no-toolchain-required design.
  class GoMod
    class NotFoundError < StandardError; end

    class << self
      # Walks upward from +start_dir+ looking for a `go.mod` file, mirroring how
      # Bundler locates `Gemfile` from the current directory.
      #
      # @param start_dir [String]
      # @return [GoMod]
      # @raise [NotFoundError] if no `go.mod` is found in +start_dir+ or any parent.
      def find(start_dir)
        dir = File.expand_path(start_dir)

        loop do
          path = File.join(dir, "go.mod")
          return parse(File.read(path)) if File.exist?(path)

          parent = File.dirname(dir)
          break if parent == dir

          dir = parent
        end

        raise(NotFoundError, "No go.mod found in #{start_dir} or any parent directory")
      end

      # @param content [String] the contents of a `go.mod` file
      # @return [GoMod]
      def parse(content)
        new(content)
      end
    end

    def initialize(content)
      @versions = {}
      parse_directives(content)
    end

    # @param module_path [String]
    # @return [String, Symbol, nil] the `v`-prefixed resolved version, +:local_replace+
    #   if replaced by an unversioned filesystem path, or +nil+ if not required.
    def resolved_version(module_path)
      @versions[module_path]
    end

    private

    def parse_directives(content)
      block = nil

      content.each_line do |raw_line|
        line = strip_comment(raw_line).strip
        next if line.empty?

        if block
          if line == ")"
            block = nil
          else
            apply_require(line) if block == :require
            apply_replace(line) if block == :replace
          end
          next
        end

        case line
        when /\Arequire\s*\(\z/
          block = :require
        when /\Areplace\s*\(\z/
          block = :replace
        when /\Arequire\s+(.+)\z/
          apply_require(Regexp.last_match(1))
        when /\Areplace\s+(.+)\z/
          apply_replace(Regexp.last_match(1))
        end
      end
    end

    def strip_comment(line)
      line.sub(%r{//.*}, "")
    end

    def apply_require(line)
      path, version = line.split(/\s+/, 2)
      return unless path && version&.start_with?("v")

      @versions[path] = version
    end

    def apply_replace(line)
      old_part, new_part = line.split("=>", 2)
      return unless old_part && new_part

      old_path = old_part.strip.split(/\s+/).first
      new_path, new_version = new_part.strip.split(/\s+/, 2)
      return unless old_path && new_path

      @versions[old_path] = new_version&.start_with?("v") ? new_version : :local_replace
    end
  end
end
