[![Gem Version](https://badge.fury.io/rb/require-hooks.svg)](https://rubygems.org/gems/require-hooks)
[![Build](https://github.com/ruby-next/require-hooks/workflows/Build/badge.svg)](https://github.com/palkan/require-hooks/actions)
[![JRuby Build](https://github.com/ruby-next/require-hooks/workflows/JRuby%20Build/badge.svg)](https://github.com/ruby-next/require-hooks/actions)
[![TruffleRuby Build](https://github.com/ruby-next/require-hooks/workflows/TruffleRuby%20Build/badge.svg)](https://github.com/ruby-next/require-hooks/actions)

# Require Hooks

Require Hooks is a library providing universal interface for injecting custom code into the Ruby's loading mechanism. It works on MRI, JRuby, and TruffleRuby.

Require hooks allows you to interfere with `Kernel#require` (incl. `Kernel#require_relative`) and `Kernel#load`.

<a href="https://evilmartians.com/">
<img src="https://evilmartians.com/badges/sponsored-by-evil-martians.svg" alt="Sponsored by Evil Martians" width="236" height="54"></a>

## Examples

- [Ruby Next][ruby-next]
- [Freezolite](https://github.com/ruby-next/freezolite)

## Installation

Add to your Gemfile:

```ruby
gem "require-hooks"
```

or gemspec:

```ruby
spec.add_dependency "require-hooks"
```

## Usage

To enable hooks, you need to load `require-hooks/setup` as early as possible. For example, in your gem's entrypoint:

```ruby
require "require-hooks/setup"
```

Then, you can add hooks:

- **around_load:** a hook that wraps code loading operation. Useful for logging and debugging purposes.

```ruby
# Simple logging
RequireHooks.around_load do |path, &block|
  puts "Loading #{path}"
  block.call.tap { puts "Loaded #{path}" }
end

# Error enrichment
RequireHooks.around_load do |path, &block|
  block.call
rescue SyntaxError => e
  raise "Oops, your Ruby is not Ruby: #{e.message}"
end
```

The return value MUST be a result of calling the passed block.

- **source_transform:** perform source-to-source transformations.

```ruby
RequireHooks.source_transform do |path, source|
  next unless path =~ /my_project\/.*/
  source ||= File.read(path)
  "# frozen_string_literal: true\n#{source}"
end
```

The return value MUST be either String (new source code) or `nil` (indicating that no transformations were performed). The second argument (`source`) MAY be `nil``, indicating that no transformer tried to transform the source code.

- **hijack_load:** a hook that is used to manually compile byte code for VM to load it.

```ruby
RequireHooks.hijack_load do |path, source|
  next unless path =~ /my_project\/.*/

  source ||= File.read(path)
  if defined?(RubyVM::InstructionSequence)
    RubyVM::InstructionSequence.compile(source)
  elsif defined?(JRUBY_VERSION)
    JRuby.compile(source)
  end
end
```

The return value is platform-specific. If there are multiple _hijackers_, the first one that returns a non-`nil` value is used, others are ignored.

## Modes

Depending on the runtime conditions, Require Hooks picks an optimal strategy for injecting the code. You can enforce a particular _mode_ by setting the `REQUIRE_HOOKS_MODE` env variable (`patch`, `load_iseq` or `bootsnap`). In practice, only setting to `patch` may makes sense.

### Via `#load_iseq`

If `RubyVM::InstructionSequence` is available, we use more robust way of hijacking code loading—`RubyVM::InstructionSequence#load_iseq`.

Keep in mind that if there is already a `#load_iseq` callback defined, it will only have an effect if Require Hooks hijackers return `nil`.

### Kernel patching

In this mode, Require Hooks monkey-patches `Kernel#require` and friends. This mode is used in JRuby by default.

### Bootsnap integration

[Bootsnap][] is a great tool to speed-up your application load and it's included into the default Rails Gemfile. And it uses `#load_iseq`. Require Hooks activates a custom Bootsnap-compatible mode, so you can benefit from both tools.

You can use require-hooks with Bootsnap to customize code loading. Just make sure you load `require-hooks/setup` after setting up Bootsnap, for example:

```ruby
require "bootsnap/setup"
require "require-hooks/setup"
```

The _around load_ hooks are executed for all files independently of whether they are cached or not. Source transformation and hijacking is only done for non-cached files.

Thus, if you introduce new source transformers or hijackers, you must invalidate the cache. (We plan to implement automatic invalidation in future versions.)

## Limitations

- `Kernel#load` with a wrap argument (e.g., `load "some_path", true` or `load "some_path", MyModule)`) is not supported (fallbacked to the original implementation). The biggest challenge here is to support constants nesting.
- Some very edgy symlinking scenarios are not supported (unlikely to affect real-world projects).

## Contributing

Bug reports and pull requests are welcome on GitHub at [https://github.com/ruby-next/require-hooks](https://github.com/ruby-next/require-hooks).

## License

The gem is available as open source under the terms of the [MIT License](http://opensource.org/licenses/MIT).

[Bootsnap]: https://github.com/Shopify/bootsnap
[ruby-next]: https://github.com/ruby-next/ruby-next
