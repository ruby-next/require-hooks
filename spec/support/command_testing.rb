# frozen_string_literal: true

require "open3"

module Kernel
  RUBY_RUNNER = if defined?(JRUBY_VERSION)
    # See https://github.com/jruby/jruby/wiki/Improving-startup-time#bundle-exec
    "jruby -G"
  else
    "bundle exec ruby"
  end

  def run_command(command, chdir: nil, should_fail: false, env: {}, input: nil)
    output, err, status =
      Open3.capture3(
        env,
        command,
        chdir: chdir || File.expand_path("../..", __dir__),
        stdin_data: input&.join("\n")
      )

    if ENV["COMMAND_DEBUG"] || (!status.success? && !should_fail)
      puts "\n\nCOMMAND:\n#{command}\n\nOUTPUT:\n#{output}\nERROR:\n#{err}\n"
    end

    status.success?.should == true unless should_fail

    yield status, output, err if block_given?
  end

  def run_ruby(command, **options, &block)
    run_command("#{RUBY_RUNNER} -rbundler/setup -I#{File.expand_path(File.join(__dir__, "../../lib"))} #{command}", **options, &block)
  end
end
