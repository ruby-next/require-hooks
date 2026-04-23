# frozen_string_literal: true

module RequireHooks
  module Bootsnap
    EMPTY_ISEQ = RubyVM::InstructionSequence.compile("").freeze

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

    module LoadIseqExt
      # Around hooks must be performed every time we trigger a file load, even if
      # the file is already cached.
      def load_iseq(path)
        ctx = RequireHooks.context_for(path)
        # Early-return for non-trackable paths
        return super if ctx.empty?

        ctx.run_around_load_callbacks(path) do
          iseq = super
          # Bootsnap returns nil when the coverage is on,
          unless iseq
            next unless defined?(Coverage) && Coverage.running?

            iseq =
              if ctx.source_transform? || ctx.hijack?
                new_contents = ctx.perform_source_transform(path)

                RequireHooks.setup_path_coverage(path, new_contents)

                hijacked = ctx.try_hijack_load(path, new_contents)

                if hijacked
                  raise TypeError, "Unsupported bytecode format for #{path}: #{hijack.class}" unless hijacked.is_a?(::RubyVM::InstructionSequence)
                  hijacked
                elsif new_contents
                  RubyVM::InstructionSequence.compile(new_contents, path, path, 1)
                end
              else
                RequireHooks.setup_path_coverage(path)
                RubyVM::InstructionSequence.compile_file(path)
              end
          end

          iseq.eval
          EMPTY_ISEQ
        end
      end
    end
  end
end

Bootsnap::CompileCache::ISeq.singleton_class.prepend(RequireHooks::Bootsnap::CompileCacheExt)
RubyVM::InstructionSequence.singleton_class.prepend(RequireHooks::Bootsnap::LoadIseqExt)
