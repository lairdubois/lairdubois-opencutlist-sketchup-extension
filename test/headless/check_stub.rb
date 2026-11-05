# Checks sketchup_stub.rb against SketchUp's own answers to stub_probes.rb.
#
#   ruby test/headless/check_stub.rb
#
# Exits 1 and prints the differing probes when the stub drifted.
require_relative 'sketchup_stub'

actual = eval(File.read(File.join(__dir__, 'stub_probes.rb'))).split("\n")
expected = File.read(File.join(__dir__, 'stub_probes.expected.txt')).split("\n")
differences = actual.each_with_index.reject { |line, index| line == expected[index] }
differences << [ "#{expected.size} expected lines, #{actual.size} probed", nil ] if actual.size != expected.size
if differences.empty?
  puts "#{actual.size} probes : the stub answers as SketchUp"
else
  differences.each { |line, index| puts index.nil? ? line : "probe #{index + 1}\n  SketchUp #{expected[index]}\n  stub     #{line}" }
  exit(1)
end
