# frozen_string_literal: true

require "bootsnap"
Bootsnap.setup(
  cache_dir: File.join(__dir__, "tmp/cache"),
  development_mode: true,
  load_path_cache: true,
  compile_cache_iseq: true,
  compile_cache_yaml: true
)

require "require-hooks/setup"

RequireHooks.source_transform do |path, source|
  raise SyntaxError, "bla-bla"
end

load File.join(__dir__, "syntax_error.rb")
