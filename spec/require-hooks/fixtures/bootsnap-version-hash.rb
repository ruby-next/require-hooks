# frozen_string_literal: true

require "bootsnap"
Bootsnap.setup(
  cache_dir: File.join(__dir__, "tmp/cache"),
  development_mode: true,
  compile_cache_iseq: true
)

require "require-hooks/setup"

RequireHooks::Bootsnap.version_hash
RequireHooks::Bootsnap.version_hash = "custom"
puts RequireHooks::Bootsnap.version_hash
