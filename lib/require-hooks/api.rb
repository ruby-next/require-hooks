# frozen_string_literal: true

module RequireHooks
  class Context
    attr_reader :around_load, :source_transform, :hijack_load,
      :patterns, :exclude_patterns

    def initialize(patterns: nil, exclude_patterns: nil)
      @patterns = patterns.freeze
      @exclude_patterns = exclude_patterns.freeze

      @around_load = []
      @source_transform = []
      @hijack_load = []

      @empty = nil
      @readonly = nil
    end

    def to_key
      [patterns, exclude_patterns]
    end

    def match?(path)
      return false unless !patterns || patterns.any? { |pattern| File.fnmatch?(pattern, path) }
      return false if exclude_patterns&.any? { |pattern| File.fnmatch?(pattern, path) }
      true
    end

    def empty?
      return @empty unless @empty.nil?
      @empty = @around_load.empty? && @source_transform.empty? && @hijack_load.empty?
    end

    def readonly?
      return @readonly unless @readonly.nil?

      @readonly = @source_transform.empty? && @hijack_load.empty?
    end

    def source_transform?
      @source_transform.any?
    end

    def hijack?
      @hijack_load.any?
    end

    def run_around_load_callbacks(path)
      return yield if @around_load.empty?

      chain = @around_load.reverse.inject do |acc_proc, next_proc|
        proc { |path, &block| acc_proc.call(path) { next_proc.call(path, &block) } }
      end

      chain.call(path) { yield }
    end

    def perform_source_transform(path)
      return unless @source_transform.any?

      source = nil

      @source_transform.each do |transform|
        source = transform.call(path, source) || source
      end

      source
    end

    def try_hijack_load(path, source)
      return unless @hijack_load.any?

      @hijack_load.each do |hijack|
        result = hijack.call(path, source)
        return result if result
      end
      nil
    end

    def merge!(another_ctx)
      around_load.concat(another_ctx.around_load)
      source_transform.concat(another_ctx.source_transform)
      hijack_load.concat(another_ctx.hijack_load)
    end
  end

  @@default_context = Context.new
  @@noop_context = Context.new
  @@contexts = {}

  class << self
    attr_accessor :print_warnings

    # Define a block to wrap the code loading.
    # The return value MUST be a result of calling the passed block.
    # For example, you can use such hooks for instrumentation, debugging purposes.
    #
    #    RequireHooks.around_load do |path, &block|
    #      puts "Loading #{path}"
    #      block.call.tap { puts "Loaded #{path}" }
    #    end
    def around_load(patterns: nil, exclude_patterns: nil, &block)
      register_hook(:around_load, block, patterns: patterns, exclude_patterns: exclude_patterns)
    end

    # Define hooks to perform source-to-source transformations.
    # The return value MUST be either String (new source code) or nil (indicating that no transformations were performed).
    #
    # NOTE: The second argument (`source`) MAY be nil, indicating that no transformer tried to transform the source code.
    #
    # For example, you can prepend each file with `# frozen_string_literal: true` pragma:
    #
    #    RequireHooks.source_transform do |path, source|
    #      "# frozen_string_literal: true\n#{source}"
    #    end
    def source_transform(patterns: nil, exclude_patterns: nil, &block)
      register_hook(:source_transform, block, patterns: patterns, exclude_patterns: exclude_patterns)
    end

    # This hook should be used to manually compile byte code to be loaded by the VM.
    # The arguments are (path, source = nil), where source is only defined if transformations took place.
    # Otherwise, you MUST read the source code from the file yourself.
    #
    # The return value MUST be either nil (continue to the next hook or default behavior) or a platform-specific bytecode object (e.g., RubyVM::InstructionSequence).
    #
    #   RequireHooks.hijack_load do |path, source|
    #     source ||= File.read(path)
    #     if defined?(RubyVM::InstructionSequence)
    #       RubyVM::InstructionSequence.compile(source)
    #     elsif defined?(JRUBY_VERSION)
    #       JRuby.compile(source)
    #     end
    #   end
    def hijack_load(patterns: nil, exclude_patterns: nil, &block)
      register_hook(:hijack_load, block, patterns: patterns, exclude_patterns: exclude_patterns)
    end

    def context_for(path)
      # Fast-track in case we have just a single non-global context defined
      if @@default_context
        return @@default_context if @@default_context.match?(path)

        return @@noop_context
      end

      matching = @@contexts.values.select { |ctx| ctx.match?(path) }

      return matching[0] || @@noop_context if matching.size < 2

      ctx = Context.new
      matching.each { |mctx| ctx.merge!(mctx) }

      ctx
    end

    # Hack to enable coverage for hooked files.
    # Requires eval coverage to be on.
    # See https://bugs.ruby-lang.org/issues/22018 (https://github.com/ruby/ruby/pull/16805)
    def setup_path_coverage(path, contents = nil)
      return unless defined?(Coverage) && Coverage.running?

      return unless eval_coverage_enabled?

      Kernel.eval("\n" * (contents || File.read(path)).lines.size, TOPLEVEL_BINDING, path, 1) # rubocop:disable Style/EvalWithLocation,Security/Eval
    end

    def contexts
      @@contexts
    end

    private

    def register_hook(type, block, patterns: nil, exclude_patterns: nil)
      @@default_context = nil
      ctx = Context.new(patterns: patterns, exclude_patterns: exclude_patterns)

      @@contexts[ctx.to_key] ||= ctx
      @@contexts[ctx.to_key].public_send(type) << block

      @@default_context = @@contexts.values.first if @@contexts.size == 1
    end

    def eval_coverage_enabled?
      return @eval_coverage_enabled if defined?(@eval_coverage_enabled)
      probe_path = File.join(__dir__, "coverage_probe.rb")
      Kernel.eval("proc { |val| val }", TOPLEVEL_BINDING, probe_path, 1) # rubocop:disable Style/EvalWithLocation

      @eval_coverage_enabled = Coverage.peek_result.key?(probe_path)
    end
  end
end
