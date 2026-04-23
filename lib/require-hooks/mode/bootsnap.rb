# frozen_string_literal: true

require "require-hooks/iseq"

module RequireHooks
  module Bootsnap
    EMPTY_ISEQ = RubyVM::InstructionSequence.compile("").freeze

    # For older Bootsnap
    module CompileCacheExt
      def input_to_storage(source, path, *)
        ctx = RequireHooks.context_for(path)
        return super if ctx.empty?

        new_contents = ctx.perform_source_transform(path)
        hijacked = ctx.try_hijack_load(path, new_contents)

        if hijacked
          raise TypeError, "Unsupported bytecode format for #{path}: #{hijack.class}" unless hijacked.is_a?(::RubyVM::InstructionSequence)
          return hijacked.to_binary
        elsif new_contents
          return RubyVM::InstructionSequence.compile(new_contents, path, path, 1).to_binary
        end

        super
      rescue SyntaxError, TypeError
        ::Bootsnap::CompileCache::UNCOMPILABLE
      end
    end

    # For new Bootsnap
    module CompilerExt
      def input_to_storage(source, path, *)
        ctx = RequireHooks.context_for(path)
        return super if ctx.empty?

        new_contents = ctx.perform_source_transform(path)
        hijacked = ctx.try_hijack_load(path, new_contents)

        if hijacked
          raise TypeError, "Unsupported bytecode format for #{path}: #{hijack.class}" unless hijacked.is_a?(::RubyVM::InstructionSequence)
          return hijacked.to_binary
        elsif new_contents
          return RubyVM::InstructionSequence.compile(new_contents, path, path, 1, @compile_options).to_binary
        end

        super
      rescue SyntaxError, TypeError
        ::Bootsnap::CompileCache::UNCOMPILABLE
      end
    end

    module LoadIseqExt
      class << self
        attr_accessor :orig_cache_dir
      end

      # Around hooks must be performed every time we trigger a file load, even if
      # the file is already cached.
      def load_iseq(path)
        ctx = RequireHooks.context_for(path)
        # Early-return for non-trackable paths
        if ctx.empty?
          ::Bootsnap::CompileCache::ISeq.cache_dir = LoadIseqExt.orig_cache_dir if LoadIseqExt.orig_cache_dir
          return super
        end

        LoadIseqExt.orig_cache_dir ||= ::Bootsnap::CompileCache::ISeq.cache_dir
        ::Bootsnap::CompileCache::ISeq.cache_dir = File.join(LoadIseqExt.orig_cache_dir, RequireHooks::Bootsnap.version_hash)

        ctx.run_around_load_callbacks(path) do
          iseq = super

          ::Bootsnap::CompileCache::ISeq.cache_dir = LoadIseqExt.orig_cache_dir

          # Bootsnap returns nil when the coverage is on,
          # we fallback to our custom #compile_with_coverage
          unless iseq
            next unless defined?(Coverage) && Coverage.running?

            iseq = RequireHooks::Iseq.compile_with_coverage(ctx, path)
          end

          iseq.eval
          EMPTY_ISEQ
        ensure
          ::Bootsnap::CompileCache::ISeq.cache_dir = LoadIseqExt.orig_cache_dir
        end
      end
    end

    class << self
      def version_hash
        @version_key ||= RequireHooks.contexts.values.map(&:to_cache_key).join("-")
      end

      attr_writer :version_hash
    end
  end

  class Context
    def to_cache_key
      Zlib.crc32(
        (around_load + source_transform + hijack_load).map do |pr|
          RubyVM::InstructionSequence.disasm(pr)
        end.join("\n")
      ).to_s
    end
  end
end

Bootsnap::CompileCache::ISeq.singleton_class.prepend(RequireHooks::Bootsnap::CompileCacheExt)
Bootsnap::CompileCache::ISeq::Compiler.prepend(RequireHooks::Bootsnap::CompilerExt) if defined?(Bootsnap::CompileCache::ISeq::Compiler)
RubyVM::InstructionSequence.singleton_class.prepend(RequireHooks::Bootsnap::LoadIseqExt)
