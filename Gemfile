# frozen_string_literal: true

source "https://rubygems.org"

gem "debug", platform: :mri
gem "bootsnap", platform: [:mri, :truffleruby]
gem "simplecov"

gemspec

eval_gemfile "gemfiles/rubocop.gemfile" unless defined?(JRuby)
