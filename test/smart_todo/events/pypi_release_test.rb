# frozen_string_literal: true

require "test_helper"

module SmartTodo
  class Events
    class PypiReleaseTest < Minitest::Test
      def test_when_package_is_released
        stub_request(:get, /pypi.org/)
          .to_return_json(body: { releases: { "1.2.0" => [] } })

        expected = "The PyPI package *foo* was released to version *1.2.0* and your TODO is now ready to be addressed."
        assert_equal(expected, pypi_release("foo", "1.2.0"))
      end

      def test_with_pessimistic_constraint
        stub_request(:get, /pypi.org/)
          .to_return_json(body: { releases: { "1.2.0" => [] } })

        expected = "The PyPI package *foo* was released to version *1.2.0* and your TODO is now ready to be addressed."
        assert_equal(expected, pypi_release("foo", "~> 1.1"))
      end

      def test_with_multiple_constraints
        stub_request(:get, /pypi.org/)
          .to_return_json(body: { releases: { "3.4.6" => [] } })

        expected = "The PyPI package *foo* was released to version *3.4.6* and your TODO is now ready to be addressed."
        assert_equal(expected, pypi_release("foo", "> 3.4.3", "< 4"))
      end

      def test_when_package_is_not_yet_released
        stub_request(:get, /pypi.org/)
          .to_return_json(body: { releases: { "1.2.0" => [], "1.2.1" => [] } })

        assert_equal(false, pypi_release("foo", "1.3.0"))
      end

      def test_when_package_does_not_exist
        stub_request(:get, /pypi.org/)
          .to_return(status: 404)

        expected = "The PyPI package *foo* doesn't seem to exist, I can't determine if " \
          "your TODO is ready to be addressed."
        assert_equal(expected, pypi_release("foo", "1.3.0"))
      end

      def test_ignores_unparseable_versions
        stub_request(:get, /pypi.org/)
          .to_return_json(body: { releases: { "1!2.0" => [], "1.2.0" => [] } })

        expected = "The PyPI package *foo* was released to version *1.2.0* and your TODO is now ready to be addressed."
        assert_equal(expected, pypi_release("foo", "1.2.0"))
      end

      private

      def pypi_release(package_name, *requirements)
        Events.new.pypi_release(package_name, *requirements)
      end
    end
  end
end
