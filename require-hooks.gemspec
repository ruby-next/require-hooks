# frozen_string_literal: true

require_relative "lib/require-hooks/version"

Gem::Specification.new do |s|
  s.name = "require-hooks"
  s.version = RequireHooks::VERSION
  s.authors = ["Vladimir Dementyev"]
  s.email = ["dementiev.vm@gmail.com"]
  s.homepage = "https://github.com/ruby-next/ruby-next"
  s.summary = "Require Hooks provide infrastructure for intercepting require/load calls in Ruby."
  s.description = "Require Hooks provide infrastructure for intercepting require/load calls in Ruby"

  s.metadata = {
    "bug_tracker_uri" => "https://github.com/ruby-next/ruby-next/issues",
    "changelog_uri" => "https://github.com/ruby-next/ruby-next/blob/master/CHANGELOG.md",
    "documentation_uri" => "https://github.com/ruby-next/ruby-next/blob/master/README.md",
    "homepage_uri" => "https://github.com/ruby-next/ruby-next",
    "source_code_uri" => "https://github.com/ruby-next/ruby-next",
    "funding_uri" => "https://github.com/sponsors/palkan"
  }

  s.license = "MIT"

  s.files = Dir.glob("lib/**/*") + %w[README.md LICENSE.txt CHANGELOG.md]
  s.require_paths = ["lib"]
  s.required_ruby_version = ">= 2.2"
end
