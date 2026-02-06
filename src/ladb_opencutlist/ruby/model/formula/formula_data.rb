module Ladb::OpenCutList

  require_relative '../data_container'

  class FormulaData < DataContainer

    def get_binding
      binding
    end

    # Utils

    def word_wrap(text, line_length = 15)
      text = text.to_s
      return text if text.empty?

      lines = []

      # Process the text paragraph by paragraph (separated by blank lines)
      paragraphs = text.split(/\n\s*\n/)

      paragraphs.each do |paragraph|
        # Replaces single line breaks with spaces
        paragraph = paragraph.gsub(/\s*\n\s*/, ' ').squeeze(' ').strip

        next if paragraph.empty?

        current_line = ""

        # Split into tokens: words and punctuation separated, but spaces after punctuation are retained
        # We cut along the spaces AND around the punctuation
        tokens = paragraph.scan(/[\w'-]+|[^\w\s'-]+/)
        tokens.each do |token|

          # If the token alone is longer than the allowed line
          if token.length > line_length
            # Adds the current line if it is not empty
            lines << current_line.strip unless current_line.strip.empty?
            # Cut the long token into pieces
            token.scan(/.{1,#{line_length}}/).each do |chunk|
              lines << chunk
            end
            current_line = ""
          elsif current_line.empty?
            # First token of the line
            current_line = token
          else
            # Determines whether a space is needed before this token
            # No space before punctuation (except for opening symbols)
            needs_space = !token.match?(/^[.,;:!?)}\]»"'…]/) || token.match?(/^[({[\[«"']/)

            test_line = if needs_space
                          current_line + " " + token
                        else
                          current_line + token
                        end

            if test_line.length <= line_length
              # The token fits on the current line
              current_line = test_line
            else
              # The token doesn't hold, we start a new line
              lines << current_line.strip
              current_line = token.lstrip
            end
          end

        end

        # Add the last line of the paragraph
        lines << current_line.strip unless current_line.strip.empty?

        # Add a blank line between paragraphs (except for the last one).
        lines << " " unless paragraph == paragraphs.last
      end

      lines.join("\n")
    end

  end

end
