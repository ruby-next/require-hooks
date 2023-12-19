# frozen_string_literal: true

require "fileutils"
require_relative "../support/command_testing"

describe "require-hooks: bootsnap mode" do
  next skip if defined?(JRUBY_VERSION) || defined?(TruffleRuby)
  # Bootsnap requires Ruby 2.3+
  next skip unless RUBY_VERSION >= "2.3.0"

  before do
    cache_path = File.join(__dir__, "fixtures", "tmp")
    if File.directory?(cache_path)
      FileUtils.rm_rf(cache_path)
    end
  end

  it "performs transformations within Bootsnap (thus caching the results)" do
    cache_path = File.join(__dir__, "fixtures", "bootsnap", "tmp")
    if File.directory?(cache_path)
      FileUtils.rm_rf(cache_path)
    end

    run_ruby(
      File.join(__dir__, "fixtures", "bootsnap.rb").to_s
    ) do |_status, output, _err|
      output.should include("Good-bye (false)\n")
      output.should include("Good-bye (true)\n")

      unless ENV["REQUIRE_HOOKS_MODE"] == "patch"
        output.should include("miss: hello.rb\n")
        misses = output.scan(/miss: (.*)$/).flatten
        misses.size.should == 1
      end
    end
  end

  it "re-raises syntax errors" do
    cache_path = File.join(__dir__, "fixtures", "bootsnap", "tmp")
    if File.directory?(cache_path)
      FileUtils.rm_rf(cache_path)
    end

    run_ruby(
      File.join(__dir__, "fixtures", "bootsnap-syntax-error.rb").to_s,
      should_fail: true
    ) do |_status, _output, err|
      err.should include("SyntaxError")
      err.should include("bootsnap-syntax-error.rb:1")
    end
  end
end
