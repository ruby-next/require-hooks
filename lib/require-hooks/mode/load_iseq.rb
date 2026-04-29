# frozen_string_literal: true

require "require-hooks/iseq"

module RequireHooks
  EMPTY_ISEQ = RubyVM::InstructionSequence.compile("").freeze

  module LoadIseq
    def load_iseq(path)
      ctx = RequireHooks.context_for(path)

      # Early-return for non-trackable paths
      return if ctx.empty?

      ctx.run_around_load_callbacks(path) do
        iseq = RequireHooks::Iseq.compile_with_coverage(ctx, path) { defined?(super) && super }

        iseq.eval
        EMPTY_ISEQ
      end
    end
  end
end

if RubyVM::InstructionSequence.respond_to?(:load_iseq)
  warn "require-hooks: RubyVM::InstructionSequence.load_iseq is already defined. It won't be used by files processed by require-hooks."
end

RubyVM::InstructionSequence.singleton_class.prepend(RequireHooks::LoadIseq)
