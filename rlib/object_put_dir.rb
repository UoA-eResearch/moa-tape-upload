#!/usr/local/bin/ruby
require_relative 'aws_connection.rb'
require_relative 'fits_metadata.rb'
require_relative 'diphot_metadata.rb'
require_relative 'log_metadata.rb'

#Recursive copy of the directory to the object store bucket
#Looks for .fit files, and if found, extracts fits metadata into a separate .info object.
# @param aws_fd [AWS_connection] S3 connection to the object store
# @param directory [String] Top level directory to recursively copy from
# @param strip_base_dir [String] Remove this from the directory path for processing naming
# @param misc_prefix [String] Using this as the object prefix, if we can't determine what it should really be
# @param metadata_log [String] Filename of log file we will add fits metadata to, as a log of the processing.
def object_put_dir(aws_fd:, directory:, strip_base_dir: nil, misc_prefix: 'misc', metadata_log: nil )
  test = false
  begin
    strip_base_dir.gsub!(/\/$/,'') if strip_base_dir != nil && strip_base_dir[-1] == '/' #Will reinsert a / later.
    misc_prefix.gsub!(/\/$/,'') if misc_prefix != nil  && misc_prefix[-1] == '/' #Will reinsert a / later.
    
    Dir.open(directory).each do |filename|
      if filename != '.' && filename != '..' #ignore parent, and current directories.
        qualified_filename =  "#{directory}/#{filename}"
        begin
          stat_record =  File.stat(qualified_filename) #It is possible for this to cause an exception if symlink points no where.
          begin
            if  stat_record.symlink? == false #Otherwise ignore
              if stat_record.directory? 
                #recurse through sub-directories.
                object_put_dir(aws_fd: aws_fd, directory: qualified_filename, strip_base_dir: strip_base_dir, misc_prefix: misc_prefix,  metadata_log: metadata_log)
              elsif stat_record.file? 
                #Process files
                begin
                  case File.extname(filename)
                  when '.fit',  '.fits' #Astro image format.
                    fm = Fits_metadata.new(directory: directory, filename: filename)
                    log_metadata(metadata_log: metadata_log, metadata: fm.full_metadata) if metadata_log != nil
                    
                    puts "aws_fd.object_put_file(filename: #{qualified_filename}, key: #{fm.obj_path}/#{filename})"
                    if !test
                      aws_fd.object_put_file(filename: qualified_filename, key: "#{fm.obj_path}/#{filename}",  metadata: fm.obj_metadata, not_if_exits: true)
                    
                      if fm.info_filename != nil
                        #Also create a .info object (Should get skipped if object exists in store, so raised an S3_Exists exception)
                        puts "aws_fd.object_put_file(info_file, key: #{fm.obj_path(filetype: 'info')}/#{fm.info_filename})"
                        aws_fd.object_put_mem(content: fm.raw_fits_metadata, 
                                           key: "#{fm.obj_path(filetype: 'info')}/#{fm.info_filename}",  
                                           metadata: {"fits_url" => "#{fm.obj_path}/#{filename}" }, #reference to the fits object as metadata
                                           not_if_exits: true
                                           )
                      end
                    else
                      puts "aws_fd.object_put_file(info_file, key: #{fm.obj_path(filetype: 'info')}/#{fm.info_filename})"
                    end
                  when '.info' #Dumps of the .fit file metadata into a separate file
                    fm = Fits_metadata.new(directory: directory, filename: filename)
                    puts "aws_fd.object_put_file(filename: #{qualified_filename}, key: #{fm.obj_path(filetype: 'info')}/#{filename})"
                    aws_fd.object_put_file(filename: qualified_filename, 
                                    key: "#{fm.obj_path(filetype: 'info')}/#{filename}",  
                                    metadata: {"fits_url" => "#{fm.obj_path}/#{filename.gsub(/info$/,'fit')}" },  #reference to the fits object as metadata
                                    not_if_exits: true
                                    )
                  when '.dat' #Diphot difference files
                    diphot = Diphot_metadata.new(directory: directory, filename: filename)
                    puts "aws_fd.object_put_file(filename: #{qualified_filename}, key: #{diphot.obj_path}/#{filename})"
                    aws_fd.object_put_file(filename: qualified_filename, key: "#{diphot.obj_path}/#{filename}",  metadata: diphot.obj_metadata, not_if_exits: true)
                  else
                    object_name = (strip_base_dir != nil && strip_base_dir != '') ? qualified_filename.gsub(/^#{strip_base_dir}\//, '') : filename
                    object_name = (misc_prefix != nil && misc_prefix != '') ? "#{misc_prefix}/#{object_name}" : object_name
                    puts "aws_fd.object_put_file(filename: #{qualified_filename}, key: #{object_name})"
                    aws_fd.object_put_file(filename: qualified_filename, key: object_name, not_if_exits: true)
                  end
                rescue S3_Exists => e #Get this if the file existed in the object store with the same MD5 sum.
                  #puts e
                rescue StandardError => error
                  $stderr.puts "Copy of \"#{qualified_filename}\" to object store failed: #{error}"
                end
              end
            end
          end
        rescue StandardError => error
          $stderr.puts "Stat of #{qualified_filename} failed with error: #{error}"
        end
      end
    end
  rescue StandardError => error
      $stderr.puts "object_put_dir(#{directory}) : #{error}"
  end 
  puts "Completed Dir #{directory}"
end

=begin
#Get an S3 connection through to the UoA object store
aws = AWS_connection.new(config_file: '../conf/conf_internal.json')   #We are inside the Uni network
tape_dir = '/home/moa/tape/185'
object_put_dir(aws_fd: aws, directory: tape_dir, strip_base_dir: tape_dir, misc_prefix: 'misc', metadata_log: "#{tape_dir.gsub(/\/$/,'')}.log" )
=end