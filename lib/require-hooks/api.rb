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
      @@default_context = nil
      ctx = Context.new(patterns: patterns, exclude_patterns: exclude_patterns)

      @@contexts[ctx.to_key] ||= ctx
      @@contexts[ctx.to_key].around_load << block

      @@default_context = @@contexts.values.first if @@contexts.size == 1
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
      @@default_context = nil
      ctx = Context.new(patterns: patterns, exclude_patterns: exclude_patterns)

      @@contexts[ctx.to_key] ||= ctx
      @@contexts[ctx.to_key].source_transform << block

      @@default_context = @@contexts.values.first if @@contexts.size == 1
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
      @@default_context = nil
      ctx = Context.new(patterns: patterns, exclude_patterns: exclude_patterns)

      @@contexts[ctx.to_key] ||= ctx
      @@contexts[ctx.to_key].hijack_load << block

      @@default_context = @@contexts.values.first if @@contexts.size == 1
    end

    def context_for(path)
      # Fast-track in case we have just a single context defined
      if @@default_context
        return @@noop_context unless @@default_context.match?(path)

        return @@default_context
      end

      matching = @@contexts.values.select { |ctx| ctx.match?(path) }

      return matching[0] || @@noop_context if matching.size < 2

      ctx = Context.new
      matching.each do |mctx|
        ctx.around_load.concat(mctx.around_load)
        ctx.source_transform.concat(mctx.source_transform)
        ctx.hijack_load.concat(mctx.hijack_load)
      end

      ctx
    end
  end
end
