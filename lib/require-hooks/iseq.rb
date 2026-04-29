# frozen_string_literal: true

module RequireHooks
  module Iseq
    class << self
      def compile_with_coverage(ctx, path)
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
          end

        RequireHooks.setup_path_coverage(path, new_contents)

        iseq ||= yield if block_given?

        iseq ||= RubyVM::InstructionSequence.compile_file(path)

        iseq
      end
    end
  end
end
