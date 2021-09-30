# Recurse through directory and its sub-directories,
# @param directory [String] directory we are recursing through
# @param strip_leadin [String] Remove this string from the front of the directory name before yielding.
# @yield directory, filename [String, String]
def walk_dir(directory:, strip_leadin: nil, &block)
  begin
    strip_leadin.gsub!(/\/$/, '') if strip_leadin != nil
    Dir.open(directory).each do |filename|
      next unless filename != '.' && filename != '..' # ignore parent, and current directories.

      qualified_filename = "#{directory}/#{filename}"
      begin
        stat_record = File.stat(qualified_filename) # It is possible for this to cause an exception if symlink points no where.
        begin
          if stat_record.symlink? == false # Otherwise ignore
            if stat_record.directory?
              # recurse through sub-directories.
              walk_dir( directory: qualified_filename, strip_leadin: strip_leadin, &block)
            elsif stat_record.file?
              # Process files
              begin
                if strip_leadin.nil?
                  yield qualified_filename, directory, filename
                elsif strip_leadin == directory
                  yield qualified_filename, '.', filename
                else
                  yield qualified_filename, directory.gsub(/^#{strip_leadin}\//, ''), filename
                end
              rescue StandardError => e
                $stderr.puts "yield failed with error: #{e}"
              end
            end
          end
        end
      rescue StandardError => e
        $stderr.puts "Stat of #{qualified_filename} failed with error: #{e}"
      end
    end
  rescue StandardError => e
    $stderr.puts "walk_dir(#{directory}) : #{e}"
  end
  # puts "Completed Dir #{directory}"
end

# walk_dir(directory: '/etc', strip_leadin: "/etc") do |full_name, dir, fn|
#   puts "'#{full_name}' '#{dir}' '#{fn}'"
# end
