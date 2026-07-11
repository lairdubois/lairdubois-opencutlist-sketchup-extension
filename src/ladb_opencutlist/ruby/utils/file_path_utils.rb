module Ladb::OpenCutList

  module FilePathUtils

    # Forbidden characters for a single segment (folder or file name) — includes /
    FORBIDDEN_CHARS_STRICT = /[<>:"\/\\|?*\x00-\x1F]/
    # Forbidden characters for a full path — excludes / to preserve path separators
    FORBIDDEN_CHARS = /[<>:"\\|?*\x00-\x1F]/
    # Leading and trailing dots
    LEADING_TRAILING_DOTS = /^\.+|\.+$/
    # Windows reserved names
    WINDOWS_RESERVED = /\A(CON|PRN|AUX|NUL|COM[1-9]|LPT[1-9])\z/i
    # Maximum length for a file or folder name
    MAX_LENGTH = 255

    # Sanitizes a folder name by removing or replacing forbidden characters
    def self.sanitize_folder_name(name, replacement: "_")
      _sanitize_segment(name, replacement: replacement)
    end

    # Sanitizes a file name while preserving its extension
    def self.sanitize_file_name(name, replacement: "_")
      return nil unless name.is_a?(String)

      ext = File.extname(name)
      base = File.basename(name, ext)

      # Sanitize base name
      base = _sanitize_segment(base, replacement: replacement)

      # Sanitize extension (remove the leading dot, sanitize, then re-add if not empty)
      if ext && !ext.empty?
        ext_without_dot = ext[1..-1] # Remove leading dot
        ext_sanitized = ext_without_dot.gsub(FORBIDDEN_CHARS_STRICT, replacement).strip
        ext = ext_sanitized.empty? ? "" : ".#{ext_sanitized}"
      else
        ext = ""
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
      name = name.gsub(FORBIDDEN_CHARS_STRICT, replacement)
      # Remove leading and trailing dots
      name = name.gsub(LEADING_TRAILING_DOTS, "")
      # Remove leading and trailing whitespace
      name = name.strip
      # Wrap Windows reserved names to avoid conflicts
      name = "_#{name}_" if !!(name =~ WINDOWS_RESERVED)
      # Fallback if name is empty after sanitization
      name = "unnamed" if name.empty?
      # Truncate to maximum allowed length
      name[0..MAX_LENGTH - 1]
    end

  end

end