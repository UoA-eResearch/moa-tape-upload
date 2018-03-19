#use system mv command to move a file to another directory
#Create the destination directory if it didn't exist.
# @param source [String] source filename
# @param destination_dir [String] directory name we want to move the file to.
def move_file(source:, destination_dir:)
  puts "mv -f #{source} #{destination_dir}"
  #return
  `/bin/mkdir -p #{destination_dir}`
  `/bin/mv -f #{source} #{destination_dir}/`
end

