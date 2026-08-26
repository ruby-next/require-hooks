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

    # Bootsnap before 1.24 does not support compiler namespaces.
    module LegacyCacheExt
      def fetch(path, cache_dir: self.cache_dir)
        ctx = RequireHooks.context_for(path)
        cache_dir = File.join(cache_dir, RequireHooks::Bootsnap.version_hash) unless ctx.empty?

        # standard:disable Style/SuperArguments
        super(path, cache_dir: cache_dir)
        # standard:enable Style/SuperArguments
      end
    end

    # Bootsnap 1.24+ compiler wrapper. Its namespace isolates transformed ISeqs
    # without changing Bootsnap's process-wide cache directory.
    class VersionedCompiler
      attr_reader :namespace, :version_hash

      def initialize(compiler, version_hash)
        @compiler = compiler
        @version_hash = version_hash
        @namespace = "#{compiler.namespace}-require-hooks-#{version_hash}"
      end

      def input_to_storage(source, path, *args)
        iseq = compile(RequireHooks.context_for(path), path, nil)
        return @compiler.input_to_storage(source, path, *args) unless iseq

        iseq.to_binary
      rescue SyntaxError, TypeError
        ::Bootsnap::CompileCache::UNCOMPILABLE
      end

      def storage_to_output(*args)
        @compiler.storage_to_output(*args)
      end

      def input_to_output(source, path, args)
        compile(RequireHooks.context_for(path), path, args) || @compiler.input_to_output(source, path, args)
      end

      private

      def compile(ctx, path, args)
        new_contents = ctx.perform_source_transform(path)
        hijacked = ctx.try_hijack_load(path, new_contents)

        if hijacked
          raise TypeError, "Unsupported bytecode format for #{path}: #{hijacked.class}" unless hijacked.is_a?(::RubyVM::InstructionSequence)
          return hijacked
        end

        return unless new_contents

        @compiler.input_to_output(new_contents, path, args) ||
          RubyVM::InstructionSequence.compile(new_contents, path, path, 1)
      end
    end

    module LoadIseqExt
      # Around hooks must be performed every time we trigger a file load, even if
      # the file is already cached.
      def load_iseq(path)
        ctx = RequireHooks.context_for(path)
        return super if ctx.empty?

        ctx.run_around_load_callbacks(path) do
          iseq = super

          # Bootsnap returns nil when the coverage is on,
          # we fallback to our custom #compile_with_coverage
          unless iseq
            next unless defined?(Coverage) && Coverage.running?

            iseq = RequireHooks::Iseq.compile_with_coverage(ctx, path)
          end

          iseq.eval
          EMPTY_ISEQ
        end
      end
    end

    class << self
      def install_compiler_selector
        iseq = ::Bootsnap::CompileCache::ISeq
        @original_compiler_selector = iseq.compiler_selector
        @compilers = {}.compare_by_identity
        iseq.compiler_selector = method(:compiler_for)
      end

      def compiler_for(path)
        iseq = ::Bootsnap::CompileCache::ISeq
        compiler = @original_compiler_selector&.call(path) || iseq.default_compiler
        return compiler if RequireHooks.context_for(path).empty?

        version_hash = RequireHooks::Bootsnap.version_hash
        cached = @compilers[compiler]
        return cached if cached&.version_hash == version_hash

        @compilers[compiler] = VersionedCompiler.new(compiler, version_hash)
      end

      def add_version_hash(value = nil, &block)
        contributor = block || value
        unless contributor.is_a?(String) || contributor.respond_to?(:call)
          raise ArgumentError, "version hash contribution must be a String or callable"
        end

        @version_hash_contributors ||= []
        @version_hash_contributors << (contributor.is_a?(String) ? contributor.dup.freeze : contributor)
        @compilers&.clear
        contributor
      end

      def version_hash
        return @version_hash unless @version_hash.nil?

        context_keys = RequireHooks.contexts.values.map(&:to_cache_key)
        contribution_keys = Array(@version_hash_contributors).map do |contributor|
          value = contributor.respond_to?(:call) ? contributor.call : contributor
          raise TypeError, "version hash contribution must return a String" unless value.is_a?(String)

          Zlib.crc32(value).to_s
        end.sort

        (context_keys + contribution_keys).join("-")
      end

      def version_hash=(version_hash)
        @version_hash = version_hash
        @compilers&.clear
      end
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

if defined?(Bootsnap::CompileCache::ISeq::Compiler)
  RequireHooks::Bootsnap.install_compiler_selector
else
  Bootsnap::CompileCache::ISeq.singleton_class.prepend(RequireHooks::Bootsnap::CompileCacheExt)
  Bootsnap::CompileCache::ISeq.singleton_class.prepend(RequireHooks::Bootsnap::LegacyCacheExt)
end
RubyVM::InstructionSequence.singleton_class.prepend(RequireHooks::Bootsnap::LoadIseqExt)
