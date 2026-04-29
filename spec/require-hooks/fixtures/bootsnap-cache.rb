# frozen_string_literal: true

require "bootsnap"
Bootsnap.setup(
  cache_dir: File.join(__dir__, "tmp/cache"),
  development_mode: true,
  load_path_cache: true,
  compile_cache_iseq: true,
  compile_cache_yaml: true
)

$events = []

Bootsnap.instrumentation = ->(event, path) {
  puts "#{event}: #{File.basename(path)}"
}

unless ENV["HOOKS"] == "false" || ARGV.include?("--no-hooks")
  require "require-hooks/setup"

  RequireHooks.source_transform(patterns: ["*/fixtures/hello.rb"]) do |path, source|
    source ||= File.read(path)
    source.gsub!("Hello", "Good-bye")
    source
  end

  RequireHooks.around_load(patterns: ["*/fixtures/hello.rb"]) do |path, &block|
    $events << "before-hook"
    puts "[before] #{File.basename(path)}"
    block.call.tap do
      puts "[after] #{File.basename(path)}"
      $events << "after-hook"
    end
  end

  if ENV["HOOKS"] == "double-transform"
    RequireHooks.source_transform(patterns: ["*/fixtures/hello.rb"]) do |path, source|
      source ||= File.read(path)
      source.gsub!("Good-bye", "Ciao")
      source
    end
  end
end

load File.join(__dir__, ARGV[0] || "hello.rb")
