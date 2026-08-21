# frozen_string_literal: true

require "test_helper"

module SmartTodo
  class GoModTest < Minitest::Test
    def test_resolves_a_single_line_require
      go_mod = GoMod.parse(<<~GO_MOD)
        module example.com/myproject

        go 1.21

        require github.com/single/line v0.5.0
      GO_MOD

      assert_equal("v0.5.0", go_mod.resolved_version("github.com/single/line"))
    end

    def test_resolves_requires_inside_a_block
      go_mod = GoMod.parse(<<~GO_MOD)
        module example.com/myproject

        go 1.21

        require (
        	github.com/foo/bar v1.2.3
        	github.com/baz/qux v0.1.0 // indirect
        )
      GO_MOD

      assert_equal("v1.2.3", go_mod.resolved_version("github.com/foo/bar"))
      assert_equal("v0.1.0", go_mod.resolved_version("github.com/baz/qux"))
    end

    def test_replace_with_version_overrides_the_required_version
      go_mod = GoMod.parse(<<~GO_MOD)
        module example.com/myproject

        require github.com/baz/replaced v1.0.0

        replace github.com/baz/replaced => github.com/baz/replaced v1.5.0
      GO_MOD

      assert_equal("v1.5.0", go_mod.resolved_version("github.com/baz/replaced"))
    end

    def test_replace_block_form_overrides_the_required_version
      go_mod = GoMod.parse(<<~GO_MOD)
        module example.com/myproject

        require github.com/baz/replaced v1.0.0

        replace (
        	github.com/baz/replaced => github.com/baz/replaced v1.5.0
        )
      GO_MOD

      assert_equal("v1.5.0", go_mod.resolved_version("github.com/baz/replaced"))
    end

    def test_replace_to_a_local_filesystem_path_has_no_version
      go_mod = GoMod.parse(<<~GO_MOD)
        module example.com/myproject

        require github.com/local/thing v1.0.0

        replace github.com/local/thing => ../local/thing
      GO_MOD

      assert_equal(:local_replace, go_mod.resolved_version("github.com/local/thing"))
    end

    def test_module_with_no_require_entry_is_nil
      go_mod = GoMod.parse(<<~GO_MOD)
        module example.com/myproject

        require github.com/foo/bar v1.2.3
      GO_MOD

      assert_nil(go_mod.resolved_version("github.com/unknown/module"))
    end

    def test_find_walks_up_from_a_nested_directory
      Dir.mktmpdir do |root|
        File.write(File.join(root, "go.mod"), "module example.com/myproject\n\nrequire github.com/foo/bar v1.2.3\n")
        nested = File.join(root, "a", "b")
        FileUtils.mkdir_p(nested)

        go_mod = GoMod.find(nested)

        assert_equal("v1.2.3", go_mod.resolved_version("github.com/foo/bar"))
      end
    end

    def test_find_raises_when_no_go_mod_is_found
      Dir.mktmpdir do |root|
        assert_raises(GoMod::NotFoundError) { GoMod.find(root) }
      end
    end
  end
end
