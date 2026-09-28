# Library Cleaner — dev-only tool that normalizes the hardware SKP files of
# the OpenCutList library.
#
# Extension registrar. Load it by adding this file's folder as an extra load
# path with the Extension Sources extension.
#
# Once loaded, use the Extensions > OCL Library Cleaner menu.

require 'sketchup.rb'
require 'extensions.rb'

module Ladb
  module LibraryCleaner

    unless file_loaded?(__FILE__)

      ex = SketchupExtension.new('OCL Library Cleaner', File.join(File.dirname(__FILE__), 'ladb_library_cleaner', 'main'))
      ex.description = 'Dev-only tool that checks and normalizes the hardware SKP files of the OpenCutList library : unique model names, no attributes, no layers, SketchUp 2017 format.'
      ex.version = '1.0.0'
      ex.creator = 'Boris Beaulant'
      ex.copyright = '2026 Boris Beaulant'
      Sketchup.register_extension(ex, true)

      file_loaded(__FILE__)
    end

  end
end
