module Ladb::OpenCutList

  module SanitizerHelper

    def _sanitize_filepath(path)
      return nil unless path.is_a?(String)
      path
        .gsub(/\x00/, '')
        .strip
    end

    def _sanitize_filename(filename)
      return nil unless filename.is_a?(String)
      filename
        .gsub('/', '∕')
        .gsub('.', '_')
        .gsub(/[\\<>:"|?*]/, ' ')
        .gsub(/\s+/, ' ')
        .strip
    end

  end

end