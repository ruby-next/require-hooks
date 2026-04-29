# frozen_string_literal: true

$events = []

if ENV["BOOTSNAP"]
  require "bootsnap"
  Bootsnap.setup(
    cache_dir: File.join(__dir__, "tmp/cache"),
    development_mode: true,
    load_path_cache: true,
    compile_cache_iseq: true,
    compile_cache_yaml: true
  )
end

require "simplecov"
# Prevent the coverage/ creation
SimpleCov.at_exit {}
SimpleCov.start do
  enable_coverage_for_eval
end

require "require-hooks/setup"

RequireHooks.around_load(patterns: ["*/fixtures/coverable.rb"]) do |path, &block|
  $events << "before-hook"
  block.call.tap { $events << "after-hook" }
end

if ENV["TRANSFORM"] == "true"
  RequireHooks.source_transform(patterns: ["*/fixtures/*.rb"]) do |path, source|
    source ||= File.read(path)
    source.gsub("cover up", "cover down")
  end
end

load File.join(__dir__, "hello.rb")
load File.join(__dir__, "coverable.rb")

puts Coverage.peek_result.map { |k, v| "#{k.gsub(__dir__, ".")}: #{v[:lines].inspect}" }.join("\n")
