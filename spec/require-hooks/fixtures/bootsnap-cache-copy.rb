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

require "require-hooks/setup"

RequireHooks.source_transform(patterns: ["*/fixtures/hello.rb"]) do |path, source|
  source ||= File.read(path)
  source.gsub!("Hello", "Hallo")
  source
end

RequireHooks.around_load(patterns: ["*/fixtures/hello.rb"]) do |path, &block|
  $events << "before-hook"
  block.call.tap { $events << "after-hook" }
end

load File.join(__dir__, "hello.rb")
