#!/usr/local/bin/ruby
require 'rubygems'
require 'net/ssh'
require 'net/scp'

HOST="sc-phy-212998.uoa.auckland.ac.nz"
BIN_DIR="/home/moa/bin"
RLIB_DIR="/home/moa/rlib"
KEY_FILE="/Users/rbur004/.ssh/moa_id_rsa"

def upload_file(scp, source, dest)
  puts "scp #{source} #{dest}"
  begin
    scp.upload!( source, dest )
  rescue Exception => error
    puts "Scp failed with error: #{error}"
  end
end

def upload_directory(host, destination)
  # use a persistent connection to transfer files
  begin
    Net::SCP.start(host, 'moa', :keys => [ KEY_FILE ]) do |scp|
      # upload a file to a remote server
      Dir.open('.').each do |filename|
        stat_record =  File.stat(filename) #It is possible for this to cause an exception if symlink points no where.
        if stat_record.file?  #ignore directories.
          upload_file(scp, filename, destination )
        end
      end
    end
  rescue Exception => error
    puts "#{error}"
  end
end


Dir.chdir "#{__dir__}/rlib" 
upload_directory(HOST, RLIB_DIR)

Dir.chdir "#{__dir__}/bin" 
upload_directory(HOST, BIN_DIR)
