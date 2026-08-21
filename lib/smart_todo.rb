# frozen_string_literal: true

require "prism"
require "smart_todo/version"
require "smart_todo/events"
require "smart_todo/source_adapters/base"
require "smart_todo/source_adapters/ruby"
require "smart_todo/source_adapters/python"
require "smart_todo/source_adapters/go"
require "smart_todo/source_adapters"

module SmartTodo
  autoload :SlackClient,              "smart_todo/slack_client"
  autoload :CLI,                      "smart_todo/cli"
  autoload :Todo,                     "smart_todo/todo"
  autoload :CommentParser,            "smart_todo/comment_parser"
  autoload :HttpClientBuilder,        "smart_todo/http_client_builder"
  autoload :GoMod,                    "smart_todo/go_mod"

  module Dispatchers
    autoload :Base,                   "smart_todo/dispatchers/base"
    autoload :Slack,                  "smart_todo/dispatchers/slack"
    autoload :Output,                 "smart_todo/dispatchers/output"
  end
end
