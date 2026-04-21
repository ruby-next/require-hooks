# This setup script creates a project structure with thousands of files to require and a single entrypoint.rb file
# to recursively load them all
#
# project/
#   entrypoint.rb
#   a/
#    a/
#      a.rb
#      b.rb
#      ...
#      h.rb
#    b/
#    ...
#    m/
#    a.rb
#   b/
#   ...
#   z/
#
# The first hierarchy level contains N folders, each next one has N/2 folders. There are log(N) levels.

require "fileutils"

N = ARGV[0]&.to_i || 100

def create_directory(n, prefix: nil, namespace: "")
  name = "a"
  nested = n / 2
  n.times do
    FileUtils.mkdir(name)
    nested_name = "a"
    nested_requires = Array.new(nested).map do
      %(require "#{prefix}#{name}/#{nested_name}").tap do
        nested_name = nested_name.succ
      end
    end

    File.write("#{name}.rb", <<~RUBY)
      module #{namespace}::#{name.capitalize}
        def foo
          "#{prefix}-bar"
        end

        attr_reader *("a".."z").to_a

        ("a".."z").each do |v|
          define_method(:"foo_\#{v}") do |input|
            input + " " + v
          end
        end
      end

      #{nested_requires.join("\n")}

      module #{namespace}::#{name.capitalize}
        include #{namespace}::#{name.capitalize}::A if defined?(include #{namespace}::#{name.capitalize}::A)
      end
    RUBY

    Dir.chdir(name) do
      create_directory(nested, prefix: "#{prefix}#{name}/", namespace: "#{namespace}::#{name.capitalize}")
    end
    name = name.succ
  end
end

root_dir = File.expand_path("project", __dir__)
FileUtils.rm_r(root_dir) if File.directory?(root_dir)
FileUtils.mkdir(root_dir)

Dir.chdir(root_dir) do
  create_directory(N)

  top_name = "a"
  top_requires = Array.new(N).map do
    %(require "#{top_name}").tap do
      top_name = top_name.succ
    end
  end

  File.write("project.rb", <<~RUBY
    $LOAD_PATH.unshift(File.join(__dir__, "../../lib"))
    $LOAD_PATH.unshift(__dir__)

    if ENV["BOOTSNAP"]
      ENV["BOOTSNAP_CACHE_DIR"] = File.expand_path("tmp/bootsnap", __dir__)
      require "bootsnap/setup"
    end

    if ENV["HOOKS"]
      require "require-hooks/setup"

      if ENV["HOOKS"].include?("around")
        $counter = 0
        patterns = ENV["HOOKS"].include?("pattern") ?  ["\#{__dir__}/*.rb"] : nil

        RequireHooks.around_load(patterns:) do |path, &block|
          block.call.tap { $counter += 1 }
        end

        at_exit { puts "Total requires: \#{$counter}" }
      end
    end

    #{top_requires.join("\n")}
  RUBY
  )
end
