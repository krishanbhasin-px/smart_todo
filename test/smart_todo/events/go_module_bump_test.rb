# frozen_string_literal: true

require "test_helper"

module SmartTodo
  class Events
    class GoModuleBumpTest < Minitest::Test
      FIXTURE = <<~GO_MOD
        module example.com/myproject

        require (
        	github.com/foo/bar v1.2.3
        	github.com/baz/replaced v1.0.0
        	github.com/local/thing v1.0.0
        )

        replace github.com/baz/replaced => github.com/baz/replaced v1.5.0
        replace github.com/local/thing => ../local/thing
        replace github.com/incompatible/mod => github.com/incompatible/mod v2.0.0+incompatible
      GO_MOD

      def test_when_module_is_bumped
        expected = "The Go module *github.com/foo/bar* was updated to version *v1.2.3* and " \
          "your TODO is now ready to be addressed."
        assert_equal(expected, go_module_bump("github.com/foo/bar", "1.2.3"))
      end

      def test_with_pessimistic_constraint
        expected = "The Go module *github.com/foo/bar* was updated to version *v1.2.3* and " \
          "your TODO is now ready to be addressed."
        assert_equal(expected, go_module_bump("github.com/foo/bar", "~> 1.1"))
      end

      def test_with_multiple_constraints
        expected = "The Go module *github.com/foo/bar* was updated to version *v1.2.3* and " \
          "your TODO is now ready to be addressed."
        assert_equal(expected, go_module_bump("github.com/foo/bar", "> 1.1", "< 2"))
      end

      def test_when_module_not_yet_bumped
        assert_equal(false, go_module_bump("github.com/foo/bar", "2"))
      end

      def test_when_module_does_not_exist_in_go_mod
        expected = "The Go module *github.com/unknown/module* is not in your dependencies, " \
          "I can't determine if your TODO is ready to be addressed."
        assert_equal(expected, go_module_bump("github.com/unknown/module", "1"))
      end

      def test_replace_directive_overrides_the_required_version
        expected = "The Go module *github.com/baz/replaced* was updated to version *v1.5.0* and " \
          "your TODO is now ready to be addressed."
        assert_equal(expected, go_module_bump("github.com/baz/replaced", "1.5.0"))
      end

      def test_local_filesystem_replace_is_reported_distinctly
        expected = "The Go module *github.com/local/thing* is locally replaced via a `replace` " \
          "directive, I can't determine if your TODO is ready to be addressed."
        assert_equal(expected, go_module_bump("github.com/local/thing", "1"))
      end

      def test_unparseable_version_does_not_satisfy
        assert_equal(false, go_module_bump("github.com/incompatible/mod", "2.0.0"))
      end

      private

      def go_module_bump(module_path, *requirements)
        Events.new(go_mod: GoMod.parse(FIXTURE)).go_module_bump(module_path, *requirements)
      end
    end
  end
end
