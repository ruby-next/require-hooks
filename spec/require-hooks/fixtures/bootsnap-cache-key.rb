# frozen_string_literal: true

require "bootsnap"
Bootsnap.setup(
  cache_dir: File.join(__dir__, "tmp/cache"),
  development_mode: true,
  load_path_cache: false,
  compile_cache_iseq: true,
  compile_cache_yaml: false
)

ENV["REQUIRE_HOOKS_MODE"] = "bootsnap"
require "require-hooks/setup"

if (keys = ENV["CACHE_KEYS"])
  keys.split(",").reject(&:empty?).each do |key|
    RequireHooks::Bootsnap.add_version_hash(key)
  end
end
if ENV["EARLY_READ"] == "true"
  RequireHooks.source_transform(patterns: ["*/fixtures/cache-key-a/**/*.rb"]) { |_path, source| source }
  first = RequireHooks::Bootsnap.version_hash

  RequireHooks.source_transform(patterns: ["*/fixtures/cache-key-b/**/*.rb"]) { |_path, source| source }
  second = RequireHooks::Bootsnap.version_hash

  puts "early_read_changed=#{first != second}"
end

puts "version_hash=#{RequireHooks::Bootsnap.version_hash}"
