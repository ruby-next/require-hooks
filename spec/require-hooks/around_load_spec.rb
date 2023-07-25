# frozen_string_literal: true

require_relative "../spec_helper"

$around_hooks_enabled = false
$events = []

# SyntaxSuggest example
RequireHooks.around_load(patterns: [File.join(__dir__, "fixtures/*.rb")], exclude_patterns: ["*/hi_jack.rb"]) do |path, &block|
  next block.call unless $around_hooks_enabled

  $events << [:before, File.basename(path)]

  block.call
end

RequireHooks.around_load(patterns: [File.join(__dir__, "fixtures/*.rb")], exclude_patterns: ["*/hi_jack.rb"]) do |path, &block|
  next block.call unless $around_hooks_enabled

  begin
    block.call
  rescue SyntaxError => e
    raise "My custom syntax error: #{e.message}"
  end
end

# rubocop:disable Lint/Void
describe "require-hooks around_load" do
  before do
    $around_hooks_enabled = true
  end

  after do
    $around_hooks_enabled = false
    $events.clear
  end

  it "invoked before and after load" do
    load File.join(__dir__, "fixtures/freeze.rb")

    Freezy.weather.should == "cold"

    $events.should == [[:before, "freeze.rb"]]
  end

  it "is not invoked when no matching files required" do
    $source_transform_enabled = false
    load File.join(__dir__, "fixtures/hi_jack.rb")

    $events.should == []
  end

  it "can catch errors" do
    -> { load File.join(__dir__, "fixtures/syntax_error.rb") }
      .should raise_error(RuntimeError, /My custom syntax error/)
  end
end
# rubocop:enable Lint/Void
