# frozen_string_literal: true

require "fileutils"
require_relative "../support/command_testing"

describe "require-hooks vs coverage" do
  # Eval coverage is only avaiable from 3.2
  next unless RUBY_VERSION >= "3.2.0"
  # Truffle doesn't support it either
  next if defined?(TruffleRuby)

  it "does not break coverage tracking" do
    run_ruby(
      File.join(__dir__, "fixtures", "coverage.rb").to_s
    ) do |_status, output, _err|
      output.should include("./hello.rb: [")
      output.should include("./coverable.rb: [1, 1, 1, nil, nil, nil, 1]\n")
    end
  end
end
