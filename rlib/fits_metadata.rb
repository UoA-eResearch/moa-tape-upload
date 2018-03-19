require_relative 'string.rb'

class Fits_metadata
  attr_reader :full_metadata          #Every field, stored in a Hash
  attr_reader :obj_metadata           #Selected fields, stored in a Hash, that we include as object store metadata
  attr_reader :raw_fits_metadata      #original raw fits metadata
  attr_reader :filename
  attr_reader :info_filename          #Substituting .info for .fit or .fits
  attr_reader :target_dir_path        #where we will write this file to (less the info/ or fits/ prefix)
  
  # @param filename [String] Fits file name with no path, as the MOA filenames have the RUN field embedded and the Fits header may not have this.
  # @param directory [String] full path to file, for openning and for error reporting.
  def initialize(directory: '.', filename:)
    @full_metadata = {}
    @obj_metadata = {}
    @raw_fits_metadata = ''
    @filename = filename
    @info_filename = ''
    @directory = directory.gsub(/\/$/, '')
    @qualified_filename = @directory + '/' + filename
    
    @filetype = filename.split('.')[-1]

    case @filetype
    when 'info'
      @info_filename = filename
      parse_info_file(filename: filename)
    when 'fit', 'fits'
      @info_filename = filename.gsub(/\.fit.*$/, '.info')
      begin
        input = `/home/moa/bin/listhead #{@qualified_filename}`
        if $? == 0
          fits_meta_to_h(fd: input)
          set_info_filename #Override the default info filename, removing the chip number.
          @list_head_failed = false
        else
          @info_filename = nil
          @list_head_failed = true
        end
      rescue StandardError => e
        puts "Fits_metadata.init(directory: #{directory}, filename: #{filename}): #{e.message}"
      end
    else
      raise "Fits_metadata.init(directory: #{directory}, filename: #{filename}): Not a fits or info file #{filename}"
    end
  end
  
  def parse_info_file
    begin
      File.open(@qualified_filename, 'rb') do |file|
        fits_meta_to_h(fd: file)
      end
    rescue StandardError => error
        $stderr.puts "Fits_metadata.parse_info_file(#{@qualified_filename}) : #{error}"
    end 
  end
  

  #DATE    = ' 09-07-10T13:24:15' / UTC date-time written
  #TIME-OBS= '        13:22:07.3' / UTC time at start of exposure [hh:mm:ss.s]
  #DATE-OBS= '        2009-07-10' / UTC date at start of exposure [ccyy-mm-dd]
  #JDSTART =       2455023.057029 / Start JD of exposure
  #JDEND   =       2455023.057726 / End JD of exposure
  #EXPTIME =                   60 / Exposure time (sec)
  #RA      = '        18:36:25.4' / Right Ascension
  #DEC     = '       -23:53:31.1' / Declination
  #RUN     = '            B20125' / Run number
  #FIELD   = '              gb22' / Field name
  #COLOUR  = '                 R' / Filter colour

  # @param fd [File]  file openned for read, or Fits header in a String
  # @return obj_metadata [Hash] Fits header as a Hash.
  def fits_meta_to_h(fd:)
    @raw_fits_metadata = ''
    date = colour = field = run = time = jdstart = jdend = exptime = ra = dec = nil
    @full_metadata['CHIP'] = "0"  #Just to have a dummy value for CCDs with only 1 chip
    @full_metadata['SERIAL'] = "0"  #Just to have a dummy value for fits files not defining a serial number
    fd.each_line do |l|
      line = l.chomp
      if line == 'FITSIO ERROR! could not open the named file' || line == 'FITSIO ERROR! error reading from FITS file'
        raise "Empty file: #{@qualified_filename}"
      end
      tokens = l.split('=')
      #Note that the fits header field names have not been consistently used (eg. FILTER and COLOUR)
      field_name = tokens[0].strip
      case field_name
      when 'TELESCO'
         @full_metadata['OBSTEL'] = tokens[1].strip_comment.unquote.strip
         l.gsub!(/^TELESCO/, 'OBSTEL ')
         
      when 'CHIP'
         l = "CHIP    =                    0 / CCD chip number\n" #Don't want chip number in the info file.
         @full_metadata['CHIP'] = tokens[1].strip_comment.unquote.strip
         
      when 'FIELD'; field = tokens[1].strip_comment.unquote.strip.upcase
      when 'OBJECT'; field ||= tokens[1].strip_comment.unquote.strip.upcase #seen 'dark','flat','focus' as objects
      when 'TARGET'; field ||= tokens[1].strip_comment.unquote.strip.upcase #seen 'dark','flat','focus' as objects

      when 'COLOUR'; colour = tokens[1].strip_comment.unquote.strip
      when 'COLOR'
        colour ||= tokens[1].strip_comment.unquote.strip
        l.gsub!(/^COLOR /, 'COLOUR')
        
      when 'FILTER'
         colour ||= tokens[1].strip_comment.unquote.strip.upcase #Can get this field instead of COLOUR.
         l.gsub!(/^FILTER/, 'COLOUR')

      when 'RUN'; run = tokens[1].strip_comment.unquote.strip
        
      when 'DATE'; date ||= tokens[1].strip_comment.unquote.strip
      when 'DATE-UTC'; date ||= tokens[1].strip_comment.unquote.strip 
      when 'EXPDATE'; date ||= tokens[1].strip_comment.unquote.strip 
      when 'DATE-OBS'; date = tokens[1].strip_comment.unquote.strip 

      when 'TIME_UTC'; time ||= tokens[1].strip_comment.unquote.strip 
      when 'TIME-OBS'; time ||= tokens[1].strip_comment.unquote.strip 
      when 'EXPSTART'; time ||= tokens[1].strip_comment.unquote.strip 

      when 'JDSTART'; jdstart = tokens[1].strip_comment.unquote.strip 
      when 'JDEND'; jdend = tokens[1].strip_comment.unquote.strip 

      when 'EXPTIME'; exptime = tokens[1].strip_comment.unquote.strip 
      when 'EXPOS'; exptime = tokens[1].strip_comment.unquote.strip #Alternate to EXPTIME

      when 'RA'; ra = tokens[1].strip_comment.unquote.strip 
      when 'RAW_RA' ; ra ||= tokens[1].strip_comment.unquote.strip

      when 'DEC'; dec = tokens[1].strip_comment.unquote.strip 
      when 'RAW_DEC'; dec ||= tokens[1].strip_comment.unquote.strip
      when 'END'
      when ''
      when /^COMMENT.*$/
        @full_metadata['COMMENT'] = tokens[0].gsub(/^COMMENT/, '').strip
      else
        if tokens[1] == nil
          fields = token[0].split(' ')
          if fields.length >= 2
            @full_metadata[fields[0]] = fields[1..-1].join(' ')
          end
        else
          @full_metadata[field_name] = tokens[1].strip_comment.unquote.strip
        end
      end
      
      @raw_fits_metadata << l
    end
  
    colour = '' if field == 'dark' #Doesn't matter what filter is used if it is a dark.

    run = @filename.split('-')[0] if run == '' #Have ~22,000 of these (out of 500,000).

    @full_metadata.merge!( {
      'FIELD' => field,
      'COLOUR' => colour,
      'RUN' => run,
      'TIME-OBS' => time,
      'DATE-OBS' => date,
      'JDSTART' => jdstart,
      'JDEND' => jdend,
      'EXPTIME' => exptime,
      'RA' => ra == '' ? '99:99:99.9' : ra,
      'DEC' => dec == '' ? '+99:99:99.9' : dec
    })
    
    ['CAMERA', 'OBSTEL', 'OBSVAT', 'DATE-OBS', 'TIME-OBS', 'RA', 'DEC', 'EPOCH', 'SERIAL', 'CHIP', 'COLOUR', 'RUN', 'FIELD', 'SET', 'JDSTART', 'JDEND', 'EXPTIME'].each do |k|
      @obj_metadata[k] = @full_metadata[k] == nil || @full_metadata[k] == '' ? 'null' : @full_metadata[k]  #UCOS rejects upload with empty strings in metadata
    end  
  end

  def set_info_filename
    @info_filename = "#{@full_metadata['RUN']}-#{@full_metadata['FIELD']}-#{@full_metadata['COLOUR']}.info"
  end
  
  #log is json lines of metadata from the fits files we have uploaded
  # @param metadata_log [String] filename of the log
  # @param metadata [String] line to append to the log file
  def metadata_log(metadata_log:, metadata:)
    File.open(metadata_log, 'a+') do |fd|
      fd.puts metadata.to_json
    end
  end
    
  #Return object path, created from fits metadata and from the original files path.
  # @param filetype [String] We want different behaviour for .fits and for .info files
  def obj_path(filetype: nil)
    if @list_head_failed == false || @full_metadata['RUN'] != nil
      filetype ||= @filetype
      if filetype == 'info' || @full_metadata['CHIP'] == nil || @full_metadata['CHIP'] == '0'
        filename = "#{@full_metadata['RUN']}-#{@full_metadata['FIELD']}-#{@full_metadata['COLOUR']}.#{filetype}"
      else
        filename = "#{@full_metadata['RUN']}-#{@full_metadata['FIELD']}-#{@full_metadata['COLOUR']}-#{@full_metadata['CHIP']}.#{filetype}"
      end
      Fits_metadata::create_path(filename: filename , directory: @directory)
    else
      Fits_metadata::create_path(filename: @filename, directory: @directory)
    end
  end
  
  #MOA filenames encode the Run-Field-colour.type
  #We use this to generate the directory hierarchy (or object path)
  # @param filename [String] We use the components ('-' separated) to create the object path
  # @param directory [String] Specific source directories can change the object path we produce.
  def self.create_path(filename:, directory: '')
    parts = filename.split('.')
    directory.upcase!

    filetype_dir = case parts[-1] #Looking for the suffix
                when 'dat'; 'diphot'  #Difference files
                when 'info'; 'info'   #Dumps of fits metadata from fits files
                when 'fit'; 'fit'     #Fits images
                when 'fits'; 'fit'    #Fits images
                else return parts[-1] #Don't know what it is we have
                end
                

    dir_components = parts[0].split('-')
    #Run: dir_components[0]
    #Field: dir_components[1]
    #Filter: dir_components[2]
    #Chip: dir_components[3]
    
    return filetype_dir if dir_components.length == 1 || dir_components[1] == '' || dir_components[1] == nil
    
    dir_components[1].upcase!
    if directory =~ /APOGEE/ #Has its own hierarchy, with TEST, FLAT, DARK, ...
      sec_dir = "#{directory.gsub(/^.*APOGEE/, 'APOGEE')}/#{filetype_dir}/#{dir_components[1]}"
    elsif directory =~ /TEST/ #Some fits file in TEST/ would otherwise get filed under non-test directories
      sec_dir = "TEST/#{filetype_dir}/#{dir_components[1]}"
    elsif directory =~ /DARK/ #Some fits file in DARK/ would otherwise get filed under non-DARK directories
      sec_dir = "DARK/#{filetype_dir}/#{dir_components[1]}"
    elsif directory =~ /FLAT/ #Some fits file in FLAT/ would otherwise get filed under non-flat directories
      sec_dir = "FLAT/#{filetype_dir}/#{dir_components[1]}"
    elsif directory =~ /FOCUS/ #Some fits file in FOCUS/ would otherwise get filed under non-FOCUS directories
      sec_dir = "FOCUS/#{filetype_dir}/#{dir_components[1]}"
    else
      sec_dir =  case dir_components[1] #Field/Object
      when /^GB/; "GB/#{filetype_dir}/GB" + "%02d" % dir_components[1][2..-1].to_i + (filetype_dir == 'diphot' || filetype_dir == 'fit' ? "%02d" % dir_components[3].to_i : '')
      when /^LMC/; "LMC/#{filetype_dir}/LMC" + "%02d" % dir_components[1][3..-1].to_i + (filetype_dir == 'diphot' || filetype_dir == 'fit' ? "%02d" % dir_components[3].to_i : '')
      when /^SMC/; "SMC/#{filetype_dir}/SMC" + "%02d" % dir_components[1][3..-1].to_i + (filetype_dir == 'diphot' || filetype_dir == 'fit' ? "%02d" % dir_components[3].to_i : '')
      when /^TR/; "TR/#{filetype_dir}/TR" + "%02d" % dir_components[1][2..-1].to_i + (filetype_dir == 'diphot' || filetype_dir == 'fit' ? "%02d" % dir_components[3].to_i : '')
      when /^OGLE/; "OGLE/#{filetype_dir}/#{dir_components[1]}"
      when /^MOA/; "MOA/#{filetype_dir}/#{dir_components[1]}"
      when /^HAYABUS/; "HAYABUS/#{filetype_dir}/#{dir_components[1]}"
      when /^RADECoffset/; "RADECoffset/#{filetype_dir}/#{dir_components[1]}"
      when /^FLAT/,/^TWIFLAT/,/^SKYFLAT/; "FLAT/#{filetype_dir}/#{dir_components[1]}"
      when /^GRB/; "GRB/#{filetype_dir}/#{dir_components[1]}"
      when /^GRD/; "GRD/#{filetype_dir}/#{dir_components[1]}"
      when /^GC/; "GC/#{filetype_dir}/#{dir_components[1]}"
      when /^STREAM/; "STREAM/#{filetype_dir}/#{dir_components[1]}"
      when /^MB/; "MB/#{filetype_dir}/#{dir_components[1]}"
      when /^GW/; "GW/#{filetype_dir}/#{dir_components[1]}"
      when /^F[0-9]/; "F/#{filetype_dir}/#{dir_components[1]}"
      when /^TPOINT/; "TPOINT/#{filetype_dir}/#{dir_components[1]}"
      when /^TEST/, /^ALERT_TEST/,/^AUTOTEST/, /^CAMTEST/; "TEST/#{filetype_dir}/#{dir_components[1]}"
      when 'DARK'; "DARK/#{filetype_dir}"
      else "#{dir_components[1]}/#{filetype_dir}"
      end
    end
    
    return sec_dir if dir_components[2] == nil || dir_components[2] == ''
    return "#{sec_dir}/#{dir_components[2]}"
  end
  
  def create_info_file
    if(@list_head_failed == false)
      pathname = obj_path(filetype: 'info')
      `/bin/mkdir -p #{pathname}`
      File.open("#{pathname}/#{@info_filename}", "w+") do |fd|
        fd.write(@raw_fits_metadata)
      end
    end
  end
  
end

=begin
fm = Fits_metadata.new(directory: '/home/rbur004', filename: 'B17662-gb9-R-99.fit' )
p fm.filename
p fm.info_filename
puts fm.obj_path(filetype: 'info')

print fm.raw_fits_metadata
p fm.full_metadata
p fm.obj_metadata
fm.create_info_file
#rescue StandardError` => e
#  puts e
=end

