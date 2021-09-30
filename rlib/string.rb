# Add unquote and strip_comment methods to String for fits header parsing.

class String
  # @return [Sting] copy of the source string, less bounding quotes after first removing trailing spaces
  def unquote
    s = self.strip
    return s[1..-2] if (s[0] == "'" && s[-1] == "'") || (s[0] == '"' && s[-1] == '"')

    return s
  end

  # @return [Sting] Fits comment is returned (part after a '/' char)
  def strip_comment
    gsub(/\/.*$/, '')
  end
end
