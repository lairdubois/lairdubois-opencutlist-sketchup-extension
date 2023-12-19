module Ladb::OpenCutList

  module SanitizerHelper

    def _sanitize_filename(filename)
      filename = filename
                   .gsub("\\", "/")
                   .gsub(/\//, '∕')
                   .gsub(/꞉/, '')
                   .gsub(/\./, '_')
      filename
    end

  end

end