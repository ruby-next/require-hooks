# Benchmarks

Purpose: measure the overhead of using require-hooks compared to not having hooks at all in various modes.

1. Setup the file structure:

```sh
ruby setup.rb 24
```

The command above creates a `project` directory with the nested Ruby files structure and the `project/project.rb` entrypoint that loads all the files. The argument (24) is the size of the first level of the nesting; at each next level the nesting decreases by 2x. So, for example, for 24, the total number of `require` calls is 12408 (24 + 24x12 + 24x12x6 + 24x12x6x3 + 24x12x6x3x1).

Every time you run the `setup.rb` script, the project folder is re-created.

2. Load the test project:

```sh
# no hooks
ruby project/project.rb

# with Bootsnap (don't forget to warmup the cache)
BOOTSNAP=1 ruby project/project.rb

# with require-hooks enabled but no hooks
HOOKS=1 ruby project/project.rb

# with an around hook that tracks the number of requires
$ HOOKS=around ruby project/project.rb

Total requires: 12408
``

3. Use hyperfine to run benhchmarks:

```sh
hyperfine --warmup 2 'ruby project/project.rb' 'HOOKS=1 ruby project/project.rb' 'HOOKS=around ruby project/project.rb' 'HOOKS=around_pattern ruby project/project.rb'

# with bootsnap
hyperfine --warmup 2 'BOOTSNAP=1 ruby project/project.rb' 'BOOTSNAP=1 HOOKS=1 ruby project/project.rb' 'BOOTSNAP=1 HOOKS=around ruby project/project.rb' 'BOOTSNAP=1 HOOKS=around_pattern ruby project/project.rb'

# load_iseq vs. kernel patch
hyperfine --warmup 2 'REQUIRE_HOOKS_MODE=load_iseq HOOKS=around ruby project/project.rb' 'REQUIRE_HOOKS_MODE=patch HOOKS=around ruby project/project.rb'
```
