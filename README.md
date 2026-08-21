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

Since TODO metadata is always evaluated as a Ruby expression regardless of the host
language, `gem_release`/`gem_bump` remain RubyGems-specific — they aren't meaningful
triggers for Python or Go dependencies. Two ecosystem-appropriate equivalents are
available instead:
```python
  # TODO(on: pypi_release('django', '5.0'), to: 'john@example.com')
  #   Upgrade once Django 5.0 is out.
```
```go
  // TODO(on: go_module_release('github.com/spf13/cobra', '> 1.8', '< 2'), to: 'john@example.com')
  //   Upgrade once a compatible cobra release is out.
```
`pypi_release` checks [pypi.org](https://pypi.org)'s JSON API; `go_module_release` checks
the [Go module proxy](https://proxy.golang.org). Both accept the same `Gem::Requirement`
version-specifier syntax as `gem_release` (e.g. `'~> 1.2'`, `'> 1', '< 2'`) so the TODO
syntax stays consistent across ecosystems — with the caveat that exotic version formats
(PEP 440 epochs/local versions on PyPI, Go pseudo-versions and `+incompatible` suffixes)
aren't guaranteed to compare correctly. `pypi_bump`/`go_module_bump` are the local-manifest equivalents of `gem_bump`
for Python and Go — no network call, reading the project's own lockfile:
```python
  # TODO(on: pypi_bump('django', '5.0'), to: 'john@example.com')
  #   Upgrade once our project's own uv.lock has picked up Django 5.0.
```
```go
  // TODO(on: go_module_bump('github.com/spf13/cobra', '> 1.8', '< 2'), to: 'john@example.com')
  //   Upgrade once our project's own go.mod has picked up a compatible cobra release.
```
`pypi_bump` reads `uv.lock` (located by walking up from the current directory
for `pyproject.toml`) — other Python lockfile formats (`poetry.lock`,
`Pipfile.lock`, `requirements.txt`) aren't supported. `go_module_bump` hand-parses
`go.mod`'s `require` and `replace` directives, walking up from the current
directory the same way — no Go toolchain required.

Documentation
----------------
Please check out the GitHub [wiki](https://github.com/Shopify/smart_todo/wiki) for documentation and example on how to setup SmartTodo in your project.

License
--------
This project is licensed under the terms of the MIT license. See the [LICENSE](LICENSE.txt) file.
