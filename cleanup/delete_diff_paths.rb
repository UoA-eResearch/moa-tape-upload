#!/usr/local/bin/ruby
# Delete the lower case version of the object,
# if there is an upper case version.

require_relative '../rlib/aws_connection.rb'

@size = 0
path = {}

DELETE = false

def human_size(n)
  if n < 1024
    '%6dB' % n
  elsif n < 1048576
    format('%4.1fKiB', (n / 1024.0))
  elsif n < 1073741824
    format('%4.1dMiB', (n / 1048576.0))
  elsif n < 1099511627776
    format('%4.1fGiB', (n / 1073741824.0))
  elsif n < 1125899906842624
    format('%4.1fTiB', (n / 1099511627776.0))
  else
    format('%4.1fPiB', (n / 1125899906842624.0))
  end
end

def delete(key)
  @aws.bucket_ls(prefix: key.gsub(/^\//, ''), delimiter: nil, versions: true ) do |o|
    puts "deleting #{o[:key]} version #{o[:version_id]} #{human_size(o[:size])}"
    @size += o[:size]
    @aws.object_delete(key: o[:key], version_id: o[:version_id]) if DELETE
  end
end

@aws = AWS_connection.new(config_file: "#{__dir__}/../conf/conf_internal.json")   # We are inside the Uni network

File.read(ARGV[0]).each_line do |s|
  s.chomp!
  puts "Processing \"#{s}\""
  tokens = s.gsub(/^Path difference /, '').gsub(/ present as /, ' ').split(' ')
  if (l = tokens.length) != 2
    t0 = tokens[0...l / 2].join(' ')
    t1 = tokens[l / 2..-1].join(' ')
    tokens[0] = t0
    tokens[1] = t1
  end

  #  if path[File.dirname(tokens[0])].nil?  && path[File.dirname(tokens[1])] != File.dirname(tokens[0])
  #    path[File.dirname(tokens[0])] = File.dirname(tokens[1])
  #  end
  case File.dirname(tokens[0])
  when /^APOGEE\/ALERT\/fit\//
    delete(tokens[1]) if tokens[1] =~ /^APOGEE\/ALERT\/ALERT\/fit\//
  when /^APOGEE\/ALERT\/ALERT\/fit\//
    delete(tokens[0]) if tokens[1] =~ /^APOGEE\/ALERT\/fit\//

  when /^APOGEE\/ALERT\/info\//
    delete(tokens[1]) if tokens[1] =~ /^APOGEE\/ALERT\/ALERT\/info\//
  when /^APOGEE\/ALERT\/ALERT\/info\//
    delete(tokens[0]) if tokens[1] =~ /^APOGEE\/ALERT\/info\//

  when /^APOGEE\/TEST\/fit\//
    delete(tokens[1]) if tokens[1] =~ /^APOGEE\/TEMP\/fit\//
  when /^APOGEE\/TEMP\/fit\//
    delete(tokens[0]) if tokens[1] =~ /^APOGEE\/TEST\/fit\//

  when /^APOGEE\/TEST\/info\//
    delete(tokens[1]) if tokens[1] =~ /^APOGEE\/TEMP\/info\//

  when /^APOGEE\/TEMP\/info\//
    delete(tokens[0]) if tokens[1] =~ /^APOGEE\/TEST\/info\//

  when /^APOGEE\/fit\/DARK\/dark/
    delete(tokens[1]) if tokens[1] =~ /^APOGEE\/DARK\/fit\/DARK\/dark\//

  when /^APOGEE\/DARK\/fit\/DARK\/dark\//
    delete(tokens[0]) if tokens[1] =~ /^APOGEE\/fit\/DARK\/dark\//

  #  when /^APOGEE\/fit\//
  #    delete(tokens[1]) if tokens[1] =~ /^APOGEE\/ALERT\/fit\//

  when /^APOGEE\/ALERT\/fit\//
    delete(tokens[0]) if tokens[1] =~ /^APOGEE\/fit\//

  when /^APOGEE\/info\/DARK\/dark/
    delete(tokens[1]) if tokens[1] =~ /^APOGEE\/DARK\/info\/DARK\/dark\//

  when /^APOGEE\/DARK\/info\/DARK\/dark\//
    delete(tokens[0]) if tokens[1] =~ /^APOGEE\/info\/DARK\/dark\//

  #  when /^APOGEE\/info\//
  #    delete(tokens[1]) if tokens[1] =~ /^APOGEE\/ALERT\/info\//

  when /^APOGEE\/ALERT\/info\//
    delete(tokens[0]) if tokens[1] =~ /^APOGEE\/info\//
  else
    puts "FAILED TO MATCH #{tokens[0]} #{tokens[1]}"
  end
end

puts "Freed #{human_size(@size)}"
