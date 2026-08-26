# frozen_string_literal: true

require "fileutils"
require_relative "../support/command_testing"

describe "require-hooks: bootsnap mode" do
  next skip if defined?(JRUBY_VERSION) || defined?(TruffleRuby)
  # Bootsnap requires Ruby 2.3+
  next skip unless RUBY_VERSION >= "2.3.0"

  before do
    @bootsnap_logs_available = ENV["REQUIRE_HOOKS_MODE"] != "patch" && RUBY_VERSION >= "2.6.0"

    cache_path = File.join(__dir__, "fixtures", "tmp")
    if File.directory?(cache_path)
      FileUtils.rm_rf(cache_path)
    end
  end

  it "performs transformations within Bootsnap (thus caching the results)" do
    run_ruby(
      File.join(__dir__, "fixtures", "bootsnap.rb").to_s
    ) do |_status, output, _err|
      output.should include("Good-bye (false)\n")
      output.should include("Good-bye (true)\n")
      output.should include("Events: before-hook, before-file, after-file, after-hook")
      output.should include("Cache directory unchanged: true\n")

      # Only when the Bootsnap mode is used
      if @bootsnap_logs_available
        output.should include("miss: hello.rb\n")
        misses = output.scan(/miss: (.*)$/).flatten
        # Since we use different folders for different hook configuration,
        # we expect to see miss, not stale
        misses.size.should == 2
      end
    end
  end

  it "allows overriding a previously read version hash" do
    run_ruby(
      File.join(__dir__, "fixtures", "bootsnap-version-hash.rb").to_s,
      env: {"REQUIRE_HOOKS_MODE" => "bootsnap"}
    ) do |_status, output, _err|
      output.should include("custom\n")
    end
  end

  it "re-raises syntax errors" do
    run_ruby(
      File.join(__dir__, "fixtures", "bootsnap-syntax-error.rb").to_s,
      should_fail: true
    ) do |_status, _output, err|
      err.should include("SyntaxError")
      err.should include("bootsnap-syntax-error.rb:1")
    end
  end

  if Gem::Version.new(Gem::Specification.find_by_name("bootsnap").version) >= Gem::Version.new("1.24.0")
    it "preserves an existing Bootsnap compiler selector" do
      run_ruby(
        File.join(__dir__, "fixtures", "bootsnap-cache.rb").to_s,
        env: {"FROZEN" => "true", "REQUIRE_HOOKS_MODE" => "bootsnap"}
      ) do |_status, output, _err|
        output.should_not include("Good-bye (false)\n")
        output.should include("Good-bye (true)\n")
      end
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
        output.should include("./coverable.rb: [1, 1, 1, nil, nil, nil, 1, 1, nil, 0, nil]\n")
      end
    end
  end

  context "cache versioning" do
    it "no hooks -> hooks -> different hooks" do
      # Run first without require hooks — loads the original file
      run_ruby(
        File.join(__dir__, "fixtures", "bootsnap-cache.rb").to_s,
        env: {"HOOKS" => "false"}
      ) do |_status, output, _err|
        output.should include("Hello (false)\n")

        if @bootsnap_logs_available
          output.should include("miss: hello.rb\n")
        end
      end

      # Now, run with hooks enabled — must invalidate
      run_ruby(
        File.join(__dir__, "fixtures", "bootsnap-cache.rb").to_s,
        env: {"HOOKS" => "true"}
      ) do |_status, output, _err|
        output.should include("Good-bye (false)\n")

        if @bootsnap_logs_available
          # !!! miss, not stale
          output.should include("miss: hello.rb\n")
        end
      end

      # Run again to make sure it's cached
      run_ruby(
        File.join(__dir__, "fixtures", "bootsnap-cache.rb").to_s,
        env: {"HOOKS" => "true"}
      ) do |_status, output, _err|
        output.should include("Good-bye (false)\n")

        if @bootsnap_logs_available
          output.should include("hit: hello.rb\n")
        end
      end

      # Run w/ different hooks
      run_ruby(
        File.join(__dir__, "fixtures", "bootsnap-cache.rb").to_s,
        env: {"HOOKS" => "double-transform"}
      ) do |_status, output, _err|
        output.should include("Ciao (false)\n")

        if @bootsnap_logs_available
          # !!! miss, not stale
          output.should include("miss: hello.rb\n")
        end
      end
    end

    it "hooks -> no hooks" do
      # Run first with require hooks
      run_ruby(
        File.join(__dir__, "fixtures", "bootsnap-cache.rb").to_s,
        env: {"HOOKS" => "true"}
      ) do |_status, output, _err|
        output.should include("Good-bye (false)\n")

        if @bootsnap_logs_available
          output.should include("miss: hello.rb\n")
        end
      end

      # Now, run without hooks and check that it loads the original file
      run_ruby(
        File.join(__dir__, "fixtures", "bootsnap-cache.rb").to_s,
        env: {"HOOKS" => "false"}
      ) do |_status, output, _err|
        output.should include("Hello (false)\n")

        if @bootsnap_logs_available
          # !!! miss, not stale
          output.should include("miss: hello.rb\n")
        end
      end
    end

    it "hooks -> different hooks (same shape)" do
      run_ruby(
        File.join(__dir__, "fixtures", "bootsnap-cache.rb").to_s
      ) do |_status, output, _err|
        output.should include("Good-bye (false)\n")
        if @bootsnap_logs_available
          output.should include("miss: hello.rb\n")
          output.should include("miss: goodbye.rb\n")
        end
      end

      run_ruby(
        File.join(__dir__, "fixtures", "bootsnap-cache.rb").to_s
      ) do |_status, output, _err|
        output.should include("Good-bye (false)\n")
        if @bootsnap_logs_available
          output.should include("hit: hello.rb\n")
          output.should include("hit: goodbye.rb\n")
        end
      end

      # Run w/ different hooks if the same shape
      run_ruby(
        File.join(__dir__, "fixtures", "bootsnap-cache-copy.rb").to_s
      ) do |_status, output, _err|
        output.should include("Hallo (false)\n")

        if @bootsnap_logs_available
          # !!! miss, not stale
          output.should include("miss: hello.rb\n")
          output.should include("hit: goodbye.rb\n")
        end
      end
    end

    it "unhooked files caching is not affected" do
      run_ruby(
        %(#{File.join(__dir__, "fixtures", "bootsnap-cache.rb")} goodbye.rb)
      ) do |_status, output, _err|
        if @bootsnap_logs_available
          output.should include("miss: api.rb\n")
          output.should include("miss: goodbye.rb\n")
        end
      end

      # Verify that loading a non-hookable file is cached
      run_ruby(
        %(#{File.join(__dir__, "fixtures", "bootsnap-cache.rb")} goodbye.rb --no-hooks)
      ) do |_status, output, _err|
        if @bootsnap_logs_available
          output.should_not include("miss: api.rb\n")
          # !!! miss, not stale
          output.should include("hit: goodbye.rb\n")
        end
      end
    end
  end
end
