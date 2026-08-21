# frozen_string_literal: true

require "test_helper"

module SmartTodo
  class LinterTest < Minitest::Test
    # Ruby / Python (both use "#")

    def test_flags_a_regular_hash_todo
      assert_equal(regular_todo_message, hash_linter.check("# TODO: Do this on January first"))
    end

    def test_flags_a_regular_hash_fixme
      assert_equal(regular_todo_message, hash_linter.check("# FIXME: this is broken"))
    end

    def test_flags_a_regular_hash_optimize
      assert_equal(regular_todo_message, hash_linter.check("# OPTIMIZE: this is slow"))
    end

    def test_accepts_a_valid_hash_smart_todo
      assert_nil(hash_linter.check("# TODO(on: date('2019-08-04'), to: 'john@example.com')"))
    end

    def test_ignores_a_comment_that_is_not_a_todo
      assert_nil(hash_linter.check("# This is just a normal comment"))
    end

    def test_flags_a_lowercase_tag_even_when_otherwise_well_formed
      assert_equal(
        regular_todo_message,
        hash_linter.check("# todo(on: date('2019-08-04'), to: 'john@example.com')"),
      )
    end

    # Go ("//")

    def test_flags_a_regular_slash_todo
      assert_equal(regular_todo_message, go_linter.check("// TODO: rewrite this loop"))
    end

    def test_accepts_a_valid_slash_smart_todo
      assert_nil(go_linter.check("// TODO(on: date('2019-08-04'), to: 'john@example.com')"))
    end

    def test_ignores_a_slash_comment_that_is_not_a_todo
      assert_nil(go_linter.check("// package main does things"))
    end

    def test_hash_linter_ignores_a_slash_comment
      assert_nil(hash_linter.check("// TODO: rewrite this loop"))
    end

    def test_go_linter_ignores_a_hash_comment
      assert_nil(go_linter.check("# TODO: Do this on January first"))
    end

    # Validation of smart TODO internals, for both markers

    def test_flags_a_smart_todo_missing_an_assignee
      assert_equal(regular_todo_message, hash_linter.check("# TODO(on: date('2019-08-04'))"))
    end

    def test_flags_a_smart_todo_with_a_malformed_on_value
      assert_equal(
        "Invalid TODO format: Incorrect `:on` event format: \"2019-08-04\". #{help_message}",
        hash_linter.check("# TODO(on: '2019-08-04', to: 'john@example.com')"),
      )
    end

    def test_flags_a_smart_todo_with_an_unknown_event_method
      assert_equal(
        "Invalid event method(s): data. #{help_message}",
        hash_linter.check("# TODO(on: data('2019-08-04'), to: 'john@example.com')"),
      )
    end

    def test_flags_a_smart_todo_with_an_invalid_date
      assert_equal(
        "Invalid date format: not-a-date. #{help_message}",
        hash_linter.check("# TODO(on: date('not-a-date'), to: 'john@example.com')"),
      )
    end

    def test_flags_a_go_smart_todo_with_an_unknown_event_method
      assert_equal(
        "Invalid event method(s): data. #{help_message}",
        go_linter.check("// TODO(on: data('2019-08-04'), to: 'john@example.com')"),
      )
    end

    def test_flags_a_go_smart_todo_with_a_wrong_arity_event
      assert_equal(
        "Invalid issue_close event: Expected 3 arguments (organization, repo, issue_number), got 1. " \
          "#{help_message}",
        go_linter.check("// TODO(on: issue_close('shopify'), to: 'john@example.com')"),
      )
    end

    private

    def hash_linter
      @hash_linter ||= Linter.new(marker: "#")
    end

    def go_linter
      @go_linter ||= Linter.new(marker: "//")
    end

    def help_message
      "For more info please look at https://github.com/Shopify/smart_todo/wiki/Syntax"
    end

    def regular_todo_message
      "Don't write regular TODO comments. Write SmartTodo compatible syntax comments. #{help_message}"
    end
  end
end
