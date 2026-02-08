module Ladb::OpenCutList

  require_relative '../data_container'

  class FormulaData < DataContainer

    def get_binding
      binding
    end

    # Utils

    def word_wrap(text, line_length = 15, line_separator = "\n")
      text = text.to_s
      return text if text.empty? || line_length < 1

      lines = []

      # Process text paragraph by paragraph (separated by empty lines)
      paragraphs = text.split(/\n\s*\n/)
      paragraphs.each do |paragraph|
        # Replace single line breaks with spaces
        paragraph = paragraph.gsub(/\s*\n\s*/, ' ').squeeze(' ').strip

        next if paragraph.empty?

        current_line = ''

        # Split on words
        tokens = paragraph.scan(/\S+/)
        tokens.each do |token|

          # If the token alone is longer than the allowed line length
          if token.length > line_length
            # Add the current line if it's not empty
            lines << current_line.strip unless current_line.strip.empty?
            # Cut the long token into chunks
            token.scan(/.{1,#{line_length}}/).each do |chunk|
              lines << chunk
            end
            current_line = ''
          elsif current_line.empty?
            # First token of the line
            current_line = token
          elsif (current_line + ' ' + token).length <= line_length
            # The token fits on the current line
            current_line += ' ' + token
          else
            # The token doesn't fit, start a new line
            lines << current_line
            current_line = token
          end

        end

        # Add the last line of the paragraph
        lines << current_line unless current_line.empty?

        # Add an empty line between paragraphs (except for the last one)
        lines << "" unless paragraph == paragraphs.last
      end

      lines.join(line_separator)
    end

  end

end
