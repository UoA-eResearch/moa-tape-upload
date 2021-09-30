# Reads multiple tar images from tape drive /dev/nst0 into the target directory
# @param [String] target directory
def read_tape(into_directory:)
  # Read until we get at least 2 EOF's on the tape
  $stderr.puts " ********************* Reading tape into #{into_directory} *********************"
  tar_count = 0
  counter = 0
  # got some tapes that work better for this
  system( '/bin/mt -f /dev/nst0 fsf' )
  system( '/bin/mt -f /dev/nst0 rewind' )
  begin
    puts "Tape file index: #{tar_count}" # Put into the stdout log, so it bounds the file list.
    $stderr.puts "Tape file index: #{tar_count}" # Also put to stderr so we can see which file image is the problem.
    system( '/bin/mt -f /dev/nst0 status' ) # Where are we on the tape.
    system( "/bin/tar --directory=#{into_directory} -xvf /dev/nst0" )
    counter = $CHILD_STATUS == 0 ? 0 : counter + 1
    system( '/bin/mt -f /dev/nst0 fsf' ) # Skip EOF marker
    tar_count += 1
  end until counter >= 1

  # Rewind and eject the tape
  puts 'Rewinding, then ejecting tape'
  system( '/bin/mt -f /dev/st0 eject' )

  $stderr.puts ' ********************* Completed. Tape may be removed  *********************'
end
