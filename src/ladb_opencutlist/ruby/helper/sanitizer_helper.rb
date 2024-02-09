module Ladb::OpenCutList

  module SanitizerHelper

    def _sanitize_filename(filename)
      filename = filename
                   .gsub(/\//, '∕')
                   .gsub(/\./, '_')
                   .gsub("\\", ' ')
                   .gsub(/</, ' ')
                   .gsub(/>/, ' ')
                   .gsub(/:/, ' ')
                   .gsub(/"/, ' ')
                   .gsub(/\|/, ' ')
                   .gsub(/\?/, ' ')
                   .gsub(/\*/, ' ')
                   .gsub(/\s+/, ' ')
                   .strip
      filename
    end

  end

end