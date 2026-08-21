# frozen_string_literal: true

require "test_helper"

module SmartTodo
  class Events
    class PypiBumpTest < Minitest::Test
      FIXTURE = <<~UV_LOCK
        version = 1
        requires-python = ">=3.11"

        [[package]]
        name = "django"
        version = "5.0.3"

        [[package]]
        name = "typing_extensions"
        version = "4.10.0"
      UV_LOCK

      def test_when_package_is_bumped
        expected = "The PyPI package *django* was updated to version *5.0.3* and " \
          "your TODO is now ready to be addressed."
        assert_equal(expected, pypi_bump("django", "5.0.3"))
      end

      def test_with_pessimistic_constraint
        expected = "The PyPI package *django* was updated to version *5.0.3* and " \
          "your TODO is now ready to be addressed."
        assert_equal(expected, pypi_bump("django", "~> 5.0"))
      end

      def test_with_multiple_constraints
        expected = "The PyPI package *django* was updated to version *5.0.3* and " \
          "your TODO is now ready to be addressed."
        assert_equal(expected, pypi_bump("django", "> 4", "< 6"))
      end

      def test_when_package_not_yet_bumped
        assert_equal(false, pypi_bump("django", "6"))
      end

      def test_when_package_does_not_exist_in_lock
        expected = "The PyPI package *flask* is not in your dependencies, I can't determine if " \
          "your TODO is ready to be addressed."
        assert_equal(expected, pypi_bump("flask", "1"))
      end

      def test_matches_via_pep_503_name_normalization
        expected = "The PyPI package *Typing-Extensions* was updated to version *4.10.0* and " \
          "your TODO is now ready to be addressed."
        assert_equal(expected, pypi_bump("Typing-Extensions", "4.10.0"))
      end

      private

      def pypi_bump(package_name, *requirements)
        Events.new(pypi_lock: PypiLock.parse(FIXTURE)).pypi_bump(package_name, *requirements)
      end
    end
  end
end
