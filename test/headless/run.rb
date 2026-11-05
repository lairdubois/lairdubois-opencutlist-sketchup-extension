# Runs TestUp suites in plain ruby, outside SketchUp, on the stand-ins of
# sketchup_stub.rb (Geom, Length…) and testup/testcase.rb - for the suites
# whose code is pure geometry. The native libs (Clippy, Meshy…) load from
# src/ladb_opencutlist/bin.
#
#   ruby test/headless/run.rb test/TC_Ladb_Worker_PanelingCompute.rb [more suites]
#   ruby test/headless/run.rb -n test_cases test/TC_Ladb_Worker_PanelingCompute.rb
#
# Exits 1 when a test fails.

$LOAD_PATH.unshift(__dir__)
require_relative 'sketchup_stub'
require 'testup/testcase'
require 'json'

module Ladb
  module OpenCutList
    PLUGIN_DIR = File.expand_path('../../src/ladb_opencutlist', __dir__)
    class Plugin
      IS_RBZ = false
    end
  end
end

only = nil
files = []
args = ARGV.dup
until args.empty?
  arg = args.shift
  arg == '-n' ? only = args.shift : files << arg
end
abort('Usage : ruby test/headless/run.rb [-n test_name] suite.rb…') if files.empty?

files.each { |file| require File.expand_path(file) }

failures = 0
count = 0
ObjectSpace.each_object(Class).select { |klass| klass < TestUp::TestCase }.sort_by(&:name).each do |klass|
  klass.public_instance_methods(true).grep(/^test_/).sort.each do |name|
    next unless only.nil? || name.to_s == only
    count += 1
    test = klass.new
    started = Time.now
    begin
      test.setup
      test.send(name)
      puts "PASS #{klass.name}##{name} (#{(Time.now - started).round(2)} s)"
    rescue Exception => e
      failures += 1
      puts "FAIL #{klass.name}##{name} (#{(Time.now - started).round(2)} s)\n  #{e.class}: #{e.message.lines.first(20).join('  ')}"
      puts e.backtrace.first(5).map { |line| "    #{line}" } unless e.is_a?(TestUp::AssertionFailed)
    ensure
      test.teardown
    end
  end
end
puts "#{count - failures}/#{count} passed"
exit(failures.zero? ? 0 : 1)
