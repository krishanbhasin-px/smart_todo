# frozen_string_literal: true

require "test_helper"

module SmartTodo
  class PypiLockTest < Minitest::Test
    def test_resolves_a_package_version
      lock = PypiLock.parse(<<~UV_LOCK)
        version = 1
        requires-python = ">=3.11"

        [[package]]
        name = "typing-extensions"
        version = "4.10.0"

        [[package]]
        name = "Django"
        version = "5.0.3"
      UV_LOCK

      assert_equal("4.10.0", lock.resolved_version("typing-extensions"))
    end

    def test_normalizes_package_names_per_pep_503
      lock = PypiLock.parse(<<~UV_LOCK)
        [[package]]
        name = "Django"
        version = "5.0.3"
      UV_LOCK

      assert_equal("5.0.3", lock.resolved_version("django"))
      assert_equal("5.0.3", lock.resolved_version("DJANGO"))
    end

    def test_normalizes_dashes_underscores_and_dots_as_equivalent
      lock = PypiLock.parse(<<~UV_LOCK)
        [[package]]
        name = "typing_extensions"
        version = "4.10.0"
      UV_LOCK

      assert_equal("4.10.0", lock.resolved_version("typing-extensions"))
      assert_equal("4.10.0", lock.resolved_version("typing.extensions"))
    end

    def test_package_not_in_lock_is_nil
      lock = PypiLock.parse(<<~UV_LOCK)
        [[package]]
        name = "django"
        version = "5.0.3"
      UV_LOCK

      assert_nil(lock.resolved_version("flask"))
    end

    def test_find_walks_up_from_a_nested_directory
      Dir.mktmpdir do |root|
        File.write(File.join(root, "pyproject.toml"), "[project]\nname = \"example\"\n")
        File.write(File.join(root, "uv.lock"), "[[package]]\nname = \"django\"\nversion = \"5.0.3\"\n")
        nested = File.join(root, "a", "b")
        FileUtils.mkdir_p(nested)

        lock = PypiLock.find(nested)

        assert_equal("5.0.3", lock.resolved_version("django"))
      end
    end

    def test_find_raises_when_no_pyproject_toml_is_found
      Dir.mktmpdir do |root|
        assert_raises(PypiLock::NotFoundError) { PypiLock.find(root) }
      end
    end

    def test_find_raises_when_pyproject_toml_exists_without_a_uv_lock
      Dir.mktmpdir do |root|
        File.write(File.join(root, "pyproject.toml"), "[project]\nname = \"example\"\n")

        assert_raises(PypiLock::NotFoundError) { PypiLock.find(root) }
      end
    end
  end
end
