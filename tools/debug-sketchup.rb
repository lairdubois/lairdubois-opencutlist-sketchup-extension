# This file accepts a argument which specify which SketchUp version to load.
# It assumes default installation location.
# Example: ruby debug-sketchup.rb 16
sketchup_version = ARGV[0].to_i

# Debugging only possible in SketchUp 2014 and newer as debugger protocol was
# introduced for Ruby 2.0.
version = "20#{sketchup_version}"

debug_args = '-rdebug "ide port=7777" -lang en'

if RUBY_PLATFORM.include?('darwin')
  # OS X
  sketchup_path = "/Applications/SketchUp\\ #{version}"
  sketchup = File.join(sketchup_path, 'SketchUp.app')
  sketchup_command = %(open -a #{sketchup} --args #{debug_args})
else
  # Windows
  program_files_32 = ENV['ProgramFiles(x86)'] || 'C:/Program Files (x86)'
  program_files_64 = ENV['ProgramW6432'] || 'C:/Program Files'

  sketchup_relative = "SketchUp/SketchUp #{version}/SketchUp.exe"
  sketchup_32 = File.join(program_files_32, sketchup_relative)
  sketchup_64 = File.join(program_files_64, sketchup_relative)

  sketchup = File.exist?(sketchup_64) ? sketchup_64 : sketchup_32
  sketchup_command = %("#{sketchup}" #{debug_args})
end

# We then start SketchUp with the special flag to make it connect to the
# debugger on the given port.
spawn(sketchup_command)