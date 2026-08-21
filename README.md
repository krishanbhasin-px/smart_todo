<h3 align="center">
  <img src="https://user-images.githubusercontent.com/8122246/61341925-b936d180-a848-11e9-95c1-0d2f398c51b1.png?raw=true" width="200">
</h3>

[![Build Status](https://github.com/Shopify/smart_todo/workflows/CI/badge.svg)](https://github.com/Shopify/smart_todo/actions?query=workflow%3ACI)

_SmartTodo_  is a library designed to assign users on TODO comments written in your codebase and help assignees be reminded when it's time to commit to their TODO.

Installation
-----------
1) Add the gem in your Gemfile.
```ruby
group :development do
  gem 'smart_todo', require: false # No need to require it
end
```
2) Run `bundle install`


Summary
---------
SmartTodo allows to write TODO comments alongside your code and assign a user to it.
When the TODO's event is met (i.e. a certain date is reached), the TODO's assignee will get pinged on Slack.

**Without SmartTodo**
```ruby
  # TODO: Warning! We need to change the API endpoint on July 1st because the provider
  # is modifying its API.
  def api_call
  end
```

-------------------

**With SmartTodo**
```ruby
  # TODO(on: date('2019-07-01'), to: 'john@example.com')
  #   The API provider is modifying its endpoint, we need to modify our code.
  def api_call
  end
```

Multi-language scanning
------------------------
SmartTodo can scan Ruby, Python, and Go source in the same run — pass a directory
containing any mix of `.rb`, `.py`, and `.go` files and each is matched against its own
comment syntax (`#` for Ruby/Python, `//` line comments for Go — Go TODOs must use `//`,
not `/* */` block comments). Only comment *extraction* is
language-specific; the `on: ..., to: ...` metadata is always parsed as a small Ruby
expression, so the syntax above is identical regardless of which language the comment
lives in — including in a Python file:
```python
  # TODO(on: date('2019-07-01'), to: 'john@example.com')
  #   The API provider is modifying its endpoint, we need to modify our code.
  def api_call():
      pass
```
or a Go file:
```go
  // TODO(on: date('2019-07-01'), to: 'john@example.com')
  //   The API provider is modifying its endpoint, we need to modify our code.
  func apiCall() {}
```
Scanning `.py` files shells out to `python3` (required on `PATH`) to tokenize comments
correctly, reusing CPython's own lexer instead of reimplementing its string/f-string
escaping rules. Scanning `.go` files uses a small pure-Ruby tokenizer — no Go toolchain
required.

The `SmartTodoCop`/`SmartTodoCommentFormatCop` RuboCop cops remain Ruby-only: they hook
RuboCop's own AST, which only parses `.rb` files. There is currently no lint-time
enforcement for Python or Go TODOs — only the `smart_todo` CLI's dispatch-time
validation applies to them.

Documentation
----------------
Please check out the GitHub [wiki](https://github.com/Shopify/smart_todo/wiki) for documentation and example on how to setup SmartTodo in your project.

License
--------
This project is licensed under the terms of the MIT license. See the [LICENSE](LICENSE.txt) file.
