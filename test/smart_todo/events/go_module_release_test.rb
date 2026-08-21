# frozen_string_literal: true

require "test_helper"

module SmartTodo
  class Events
    class GoModuleReleaseTest < Minitest::Test
      def test_when_module_is_released
        stub_request(:get, %r{proxy.golang.org/.*/@v/list})
          .to_return(body: "v1.2.0\n")

        expected = "The Go module *example.com/foo* was released to version *v1.2.0* and " \
          "your TODO is now ready to be addressed."
        assert_equal(expected, go_module_release("example.com/foo", "1.2.0"))
      end

      def test_with_pessimistic_constraint
        stub_request(:get, %r{proxy.golang.org/.*/@v/list})
          .to_return(body: "v1.2.0\n")

        expected = "The Go module *example.com/foo* was released to version *v1.2.0* and " \
          "your TODO is now ready to be addressed."
        assert_equal(expected, go_module_release("example.com/foo", "~> 1.1"))
      end

      def test_with_multiple_constraints
        stub_request(:get, %r{proxy.golang.org/.*/@v/list})
          .to_return(body: "v3.4.6\n")

        expected = "The Go module *example.com/foo* was released to version *v3.4.6* and " \
          "your TODO is now ready to be addressed."
        assert_equal(expected, go_module_release("example.com/foo", "> 3.4.3", "< 4"))
      end

      def test_when_module_is_not_yet_released
        stub_request(:get, %r{proxy.golang.org/.*/@v/list})
          .to_return(body: "v1.2.0\nv1.2.1\n")

        assert_equal(false, go_module_release("example.com/foo", "1.3.0"))
      end

      def test_when_module_does_not_exist
        stub_request(:get, %r{proxy.golang.org/.*/@v/list})
          .to_return(status: 404)

        expected = "The Go module *example.com/foo* doesn't seem to exist, I can't determine if " \
          "your TODO is ready to be addressed."
        assert_equal(expected, go_module_release("example.com/foo", "1.3.0"))
      end

      def test_ignores_unparseable_versions
        stub_request(:get, %r{proxy.golang.org/.*/@v/list})
          .to_return(body: "v2.0.0+incompatible\nv1.2.0\n")

        expected = "The Go module *example.com/foo* was released to version *v1.2.0* and " \
          "your TODO is now ready to be addressed."
        assert_equal(expected, go_module_release("example.com/foo", "1.2.0"))
      end

      def test_pseudo_versions_do_not_spuriously_satisfy_requirements
        stub_request(:get, %r{proxy.golang.org/.*/@v/list})
          .to_return(body: "v0.0.0-20200101000000-abcdef123456\n")

        assert_equal(false, go_module_release("example.com/foo", "1.2.0"))
      end

      def test_escapes_uppercase_letters_in_module_path
        stub_request(:get, "https://proxy.golang.org/github.com/!burnt!sushi/toml/@v/list")
          .to_return(body: "v1.0.0\n")

        expected = "The Go module *github.com/BurntSushi/toml* was released to version *v1.0.0* and " \
          "your TODO is now ready to be addressed."
        assert_equal(expected, go_module_release("github.com/BurntSushi/toml", "1.0.0"))
      end

      private

      def go_module_release(module_path, *requirements)
        Events.new.go_module_release(module_path, *requirements)
      end
    end
  end
end
