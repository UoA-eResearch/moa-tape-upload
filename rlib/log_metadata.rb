require 'json'

#log is json lines of metadata from the fits files we have uploaded
# @param metadata_log [String] filename of the log
# @param metadata [String] line to append to the log file
def log_metadata(metadata_log:, metadata:)
  File.open(metadata_log, 'a+') do |fd|
    fd.puts metadata.to_json
  end
end
