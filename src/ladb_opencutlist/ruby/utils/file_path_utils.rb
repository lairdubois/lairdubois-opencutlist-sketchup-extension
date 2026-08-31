module Ladb::OpenCutList

  module FilePathUtils

    # Forbidden characters for a single segment (folder or file name) — includes /
    FORBIDDEN_CHARS_STRICT = /[<>:"\/\\|?*\x00-\x1F]/
    # Forbidden characters for a full path — excludes / to preserve path separators
    FORBIDDEN_CHARS = /[<>:"\\|?*\x00-\x1F]/
    # Trailing dots — leading dots are kept, they are part of the name
    TRAILING_DOTS = /\.+\z/
    # Windows reserved names
    WINDOWS_RESERVED = /\A(CON|PRN|AUX|NUL|COM[1-9]|LPT[1-9])\z/i
    # Maximum length for a file or folder name
    MAX_LENGTH = 255
    # File extension of a single segment — the separators are NOT considered as
    # such here, they are legit characters of the name (see .sanitize_file_name)
    SEGMENT_EXTNAME = /\A(.+)(\.[^.\/\\]+)\z/

    # Visually similar (and allowed) Unicode substitutes for forbidden characters.
    # They keep the name readable when the forbidden character carries a meaning
    # (typically a "/" used as a separator inside a part name).
    SIMILAR_CHARS = {
      '/'  => "\u2215",   # DIVISION SLASH
      '\\' => "\u29F5",   # REVERSE SOLIDUS OPERATOR
      ':'  => "\u02D0",   # MODIFIER LETTER TRIANGULAR COLON
      '*'  => "\u2217",   # ASTERISK OPERATOR
      '?'  => "\uFF1F",   # FULLWIDTH QUESTION MARK
      '"'  => "\u201D",   # RIGHT DOUBLE QUOTATION MARK
      '<'  => "\u2039",   # SINGLE LEFT-POINTING ANGLE QUOTATION MARK
      '>'  => "\u203A",   # SINGLE RIGHT-POINTING ANGLE QUOTATION MARK
      '|'  => "\u2223"    # DIVIDES
    }

    # Sanitizes a folder name by removing or replacing forbidden characters
    def self.sanitize_folder_name(name, replacement: "_")
      _sanitize_segment(name, replacement: replacement)
    end

    # Sanitizes a file name while preserving its extension.
    # The given name is considered as a *single* segment : a "/" (or a "\") is
    # part of the name and is replaced by a similar character, it does not split
    # the name (File.basename("C4.Ti.Face/1.dxf") would return "1.dxf").
    def self.sanitize_file_name(name, replacement: "_")
      return nil unless name.is_a?(String)

      # Split base name and extension without File.extname / File.basename which
      # would truncate the name at the last path separator
      if (m = SEGMENT_EXTNAME.match(name))
        base = m[1]
        ext = m[2]
      else
        base = name
        ext = ""
      end

      # Sanitize base name
      base = _sanitize_segment(base, replacement: replacement)

      # Sanitize extension (remove the leading dot, sanitize, then re-add if not empty)
      unless ext.empty?
        ext_sanitized = _replace_forbidden_chars(ext[1..-1], replacement).strip
        ext = ext_sanitized.empty? ? "" : ".#{ext_sanitized}"
      end

      # Reassemble
      full_name = "#{base}#{ext}"

      # Truncate to max length, ensuring we don't split multibyte characters
      if full_name.length > MAX_LENGTH
        full_name = full_name[0...MAX_LENGTH]
        # Ensure valid UTF-8 by removing potentially broken trailing bytes
        full_name = full_name.scrub("")
      end

      full_name
    end

    # Sanitizes a full file path by sanitizing each segment individually,
    # while preserving the path separator (Unix or Windows)
    def self.sanitize_file_path(path, replacement: "_")
      return nil unless path.is_a?(String)

      # Preserve Windows drive letter if present
      drive = ""
      normalized_path = path
      if path =~ /\A([a-zA-Z]:)(.*)/
        drive = $1
        normalized_path = $2
      end

      dir  = File.dirname(normalized_path)
      file = File.basename(normalized_path)

      # Sanitize each folder segment individually
      sanitized_dir = dir.split(File::SEPARATOR)
                         .map { |folder| folder.empty? ? folder : _sanitize_segment(folder, replacement: replacement) }
                         .join(File::SEPARATOR)

      # Sanitize the file name
      sanitized_file = sanitize_file_name(file, replacement: replacement)

      # Reconstruct the path
      result = if sanitized_file.is_a?(String) && !sanitized_file.empty?
                 File.join(sanitized_dir, sanitized_file)
               else
                 sanitized_dir
               end

      # Re-add Windows drive letter if it was present
      drive.empty? ? result : "#{drive}#{result}"
    end

    # Sanitizes a Windows-style path by replacing backslashes with forward slashes
    def self.sanitize_fucking_windows_backslashes(path)
      path.gsub(/\\/, '/')
    end

    # -----

    private

    # Shared private helper that sanitizes a single path segment (folder or file base name)
    def self._sanitize_segment(name, replacement: "_")
      # Replace forbidden characters
      name = _replace_forbidden_chars(name, replacement)
      # Remove leading and trailing whitespace
      name = name.strip
      # Remove trailing dots (and the whitespace they could uncover)
      name = name.gsub(TRAILING_DOTS, "").strip
      # Wrap Windows reserved names to avoid conflicts
      name = "_#{name}_" if !!(name =~ WINDOWS_RESERVED)
      # Fallback if name is empty after sanitization
      name = "unnamed" if name.empty?
      # Truncate to maximum allowed length
      name[0..MAX_LENGTH - 1]
    end

    # Replaces forbidden characters by a visually similar one when it exists,
    # by the given replacement otherwise
    def self._replace_forbidden_chars(name, replacement)
      name.gsub(FORBIDDEN_CHARS_STRICT) { |char| SIMILAR_CHARS.fetch(char, replacement) }
    end

  end

end
