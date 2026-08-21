# frozen_string_literal: true

require "toml-rb"

module SmartTodo
  # Resolves a PyPI package name to its locally-locked version by parsing
  # `uv.lock`. `pyproject.toml` is only used to locate the project root; its
  # contents are never parsed.
  class PypiLock
    class NotFoundError < StandardError; end

    class << self
      # Walks upward from +start_dir+ looking for `pyproject.toml`, then reads
      # `uv.lock` from that same directory.
      #
      # @param start_dir [String]
      # @return [PypiLock]
      # @raise [NotFoundError] if no `pyproject.toml` is found in +start_dir+ or any
      #   parent, or if it's found without a `uv.lock` alongside it.
      def find(start_dir)
        dir = File.expand_path(start_dir)

        loop do
          pyproject_path = File.join(dir, "pyproject.toml")

          if File.exist?(pyproject_path)
            lock_path = File.join(dir, "uv.lock")
            unless File.exist?(lock_path)
              raise(NotFoundError, "Found pyproject.toml at #{dir} but no uv.lock alongside it")
            end

            return parse(File.read(lock_path))
          end

          parent = File.dirname(dir)
          break if parent == dir

          dir = parent
        end

        raise(NotFoundError, "No pyproject.toml found in #{start_dir} or any parent directory")
      end

      # @param toml_content [String] the contents of a `uv.lock` file
      # @return [PypiLock]
      def parse(toml_content)
        new(TomlRB.parse(toml_content))
      end
    end

    def initialize(data)
      @versions = {}

      Array(data["package"]).each do |package|
        name = package["name"]
        version = package["version"]
        next unless name && version

        @versions[normalize(name)] = version
      end
    end

    # @param package_name [String]
    # @return [String, nil]
    def resolved_version(package_name)
      @versions[normalize(package_name)]
    end

    private

    # PEP 503 name normalization: case-insensitive, with "-", "_", and "." runs
    # treated as equivalent.
    #
    # @param name [String]
    # @return [String]
    def normalize(name)
      name.downcase.gsub(/[-_.]+/, "-")
    end
  end
end
