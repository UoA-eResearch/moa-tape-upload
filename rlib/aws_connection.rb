#!/usr/local/bin/ruby

require 'wikk_configuration' #json to class with accessor methods
require 'aws-sdk' #gem install aws-sdk
require 'digest'
require_relative 's3_exists.rb'
=begin 
#Example

  aws = AWS_connection.new(config_file: '../conf/conf_internal.json')

  begin
    aws.s3_client.list_buckets.buckets.each do |bucket|
      puts "#{bucket.name}\t#{bucket.creation_date}"
    end
  rescue StandardError => error
      puts "buckets() : #{error}"
  end 
=end

class AWS_connection
  attr_reader :s3_client, :bucket, :conf, :resp
  
  #Create aws S3 connection
  # @param config_file [String|Hash] If String, then this a filename to read json into a Hash. If Hash, then this is the config.                         
  def initialize(config_file:)
    @conf = WIKK::Configuration.new(config_file)
    @bucket = @conf.vault

    Aws.config.update(
            endpoint: "https://#{@conf.host}:#{@conf.port}",
            access_key_id: @conf.access_id,
            secret_access_key: @conf.access_key,
            force_path_style: true,
            region: 'us-east-1', #Actually at UoA
            ssl_verify_peer: false #We are using a self signed Cert.
    )

    @s3_client = Aws::S3::Client.new
  end
  
  #Fetch the object's header's md5 value (nil if no object)
  # @param key [String] Object reference (bucket is already known)
  # @return md5 [String] MD5 checksum as a hexstring (Mac/FreeBSD equivalent is /sbin/md5. Linux equivalent is /usr/bin/md5sum)
  def obj_md5(key:)
    begin
      @resp = @s3_client.head_object(bucket: @bucket, key: key)
      return resp.etag.gsub(/"/, '')
    rescue Aws::S3::Errors::NotFound => error
      return nil
    rescue   StandardError => error
      $stderr.puts "obj_md5(#{bucket}) : #{error.class} #{error}"
    end
  end
  
  #Uses systems md5sum to fetch the file's md5
  # @param filename [String] Path to the file
  # @return md5 [String] MD5 checksum as a hexstring (Mac/FreeBSD equivalent is /sbin/md5. Linux equivalent is /usr/bin/md5sum)
  def file_md5(filename:)
    md5 = `/usr/bin/md5sum #{filename}`.split(' ')[0].strip # Linux
    return $? == 0 ? md5 : nil
    #`/sbin/md5 #{filename}`.split(' ')[-1].strip # Mac OS
  end
  
  #Generate an MD5 of a string in memory
  # @param content [String] Doing an MD5 of this string
  # @return [String] MD5, as you would get from the Object stare (or /usr/bin/md5sum on Linux and /sbin/md5 on FreeBSD/Mac)
  def memory_md5(content:)
    Digest::MD5.hexdigest(content)
  end
  
  #copy file to object store
  # @param filename [String] File we want to copy to the object store
  # @param key [String] Object name that will be used in the object store
  # @param metadata [Hash] Metadata will be attached to object
  # @param not_if_exists [Boolean] If true, we don't upload the object if it is already in the object store, with the same MD5
  def object_put_file(filename:, key: ,  metadata: nil, not_if_exits: true)
    begin
      if not_if_exits
        begin
          md5 = obj_md5(key: key)
          if md5 != nil && md5 == file_md5(filename: filename) #Already in object store with same MD5 checksum.
            raise S3_Exists "Already present: '#{key}'"
          end
        rescue StandardError => error
          $stderr.puts "AWS_connection(#{@bucket}).object_put_file(#{key}) MD5: #{error}"
        end 
      end
      #Binary read on file
      File.open(filename, 'rb') do |file|
        begin
          @s3_client.put_object(bucket: @bucket, key: key, body: file, metadata: metadata)
        rescue StandardError => error
          raise "AWS_connection(#{@bucket}).object_put_file(key: #{key}) put_object: #{error}"
        end 
      end
    rescue StandardError => error
      raise "AWS_connection(#{@bucket}).object_put_file(key: #{key}) : #{error}"
    end 
  end
  
  #copy file to object store
  # @param content [String] String in memory we want to copy to the object store
  # @param content_type [String] Objects content type. Defaults to 'text/plain'
  # @param key [String] Object name that will be used in the object store
  # @param metadata [Hash] Metadata will be attached to object
  # @param not_if_exists [Boolean] If true, we don't upload the object if it is already in the object store, with the same MD5
  def object_put_mem(content:,  key: ,  metadata: nil, content_type: 'text/plain', not_if_exits: true)
    begin
      if not_if_exits
        begin
          md5 = obj_md5(key: key)
          if md5 != nil && md5 == memory_md5(content: content) #Already in object store with same MD5 checksum.
            #$stderr.puts "Ignoring, as Already present #{key}."
            return
          end
        rescue StandardError => error
          $stderr.puts "AWS_connection(#{@bucket}).object_put_mem(#{key}) MD5: #{error}"
        end
      end
      resp = @s3_client.put_object(
              key: key,
              body: content,
              bucket: @bucket,
              content_type: content_type,
              metadata: metadata
      )
      #puts "MD5: #{resp.etag}"
    rescue StandardError => error
        $stderr.puts "AWS_connection(#{@bucket}).object_put_mem(#{key}): #{error}"
    end 
  end
  
  #ls of the object store
  # @param prefix [String] optional prefix to limit the results (see S3 SDK)
  # @param delimiter [String] optional delimiter character to limit the results (see S3 SDK)
  # @yield object [Aws::S3::Types::Object] if block is given, otherwise puts object attributes to stdout. 
  def bucket_ls(prefix: nil, delimiter: nil)
    begin
      size = 0
      count = 0
      next_marker = nil
      objects = nil
      begin
        objects = @s3_client.list_objects(bucket: @bucket, prefix: prefix, delimiter: delimiter, :marker => next_marker)
        break if objects == nil
        if block_given?
          objects.contents.each do |object|
            yield object
          end
        else
          objects.contents.each do |object|
                  puts "#{object.key}\t#{object.last_modified}\t#{object.owner.id}\t#{object.owner.display_name}\t#{object.size}"
                  size += object.size
                  count += 1
          end
        end
        next_marker = objects.next_marker
      end until objects.is_truncated == false
      unless block_given?
        puts "bucket_ls: Total #{count} Files #{size/(1024.0 * 1024.0 * 1024.0)}GiB" 
      end
    rescue StandardError => error
        puts "bucket_ls(#{@bucket}) : #{error}"
    end 
  end
  
  #Copy an object from one bucket to another (or the same bucket, with a different key)
  # @param src_bucket [String] If null, then the current bucket is used
  # @param src_key [String] The object to copy
  # @param dest_bucket [String] bucket to copy source object to.
  # @param dest_key [String] The destination objects key (name)
  def object_copy(src_bucket: nil, src_key:, dest_bucket:, dest_key:)
    begin
      src_bucket ||= @bucket
      @s3_client.copy_object( copy_source: "/#{src_bucket}/#{src_key}", bucket: dest_bucket, key: dest_key, metadata_directive: "COPY")
    rescue  StandardError => error
      puts "object_copy(#{src_bucket},#{src_key},#{dest_bucket},#{dest_key}) : #{error}"
    end
  end
  
  #Copy one bucket to another, skipping content already in the destination bucket.
  # @param src_bucket [String] If null, then the current bucket is used
  # @param dest_bucket [String] bucket to rsync source bucket objects to.
  def rsync(src_bucket: nil, dest_bucket:)
    src_bucket ||= @bucket
    dest_dir_list = {}
    bucket_ls(bucket: dest_bucket) { |o| dest_dir_list[o.key] = o.etag }
    count = size = 0
    bucket_ls(bucket: src_bucket) do |object|
      if dest_dir_list[object.key] == nil || dest_dir_list[object.key] != object.etag
        print "#{object.key}\r"
        object_copy(src_bucket: src_bucket, src_key: object.key, dest_bucket: dest_bucket, dest_key: object.key)
        size += object.size
        count += 1
      end
    end
    puts "\nCopied: #{count} files, Total #{size/(1024.0 * 1024.0 * 1024.0)}GiB"
  end

  #Get the object count and total size (in Bytes) of the objects in the bucket
  # @param prefix [String] optional prefix to limit the results (see S3 SDK)
  # @param delimiter [String] optional delimiter character to limit the results (see S3 SDK)
  def bucket_stats(prefix: nil, delimiter: nil)
    begin
      size = count = 0.0
      bucket_ls(prefix: prefix, delimiter: delimiter) do |object|
        size += object.size
        count += 1
      end
    rescue StandardError => error
        puts "bucket_size(#{@bucket}) : #{error}"
    end 
    return count, size
  end
  
end

