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
      output.should include("Events: before-hook, before-file, after-file, after-hook")

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

  context "coverage" do
    # Eval coverage is only avaiable from 3.2
    next unless RUBY_VERSION >= "3.2.0"

    it "does not break coverage tracking" do
      run_ruby(
        File.join(__dir__, "fixtures", "coverage.rb").to_s,
        env: {"BOOTSNAP" => "1"}
      ) do |_status, output, _err|
        output.should include("./hello.rb: [")
        output.should include("./coverable.rb: [1, 1, 1, nil, nil, nil, 1]\n")
      end
    end
  end
end
