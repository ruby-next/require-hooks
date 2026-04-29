$events << "before-file"

# Ruby 3.4 introduced chilled strings that
# pretend to be frozen (i.e., responds with true to #frozen?).
# That will probably change in the final release though:
#   https://bugs.ruby-lang.org/issues/20205#note-45
def frozen?(str)
  str.sub!(/$/, "x")
  str.sub!(/x$/, "")
  false
rescue FrozenError
  true
end

str = "Hello"
puts str + " (#{frozen?(str)})"

# Load a file that out of the hooks scope to ensure that
# its cache is not affected by require-hooks
load File.join(__dir__, "goodbye.rb")

$events << "after-file"
