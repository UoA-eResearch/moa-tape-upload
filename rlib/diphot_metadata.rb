class Diphot_metadata
  attr_reader :obj_metadata           #Selected fields, stored in a Hash, that we include as object store metadata
  attr_reader :filename
  attr_reader :target_dir_path        #where we will write this file to (less the info/ or fits/ prefix)

  
  def initialize(directory:  '.', filename:)
    @directory = directory.gsub(/\/$/, '')
    @qualified_filename = @directory + '/' + filename
    @filename = filename
    @obj_metadata = {} #If we failed to read file
    diphot_metadata_to_h if(File.extname(filename) == '.dat')
  end
  
  #Extract metadata from diphot files
  def diphot_metadata_to_h
    File.open(@qualified_filename, "r") do |fd|
      diff = fd.readline.chomp
      reference = fd.readline.chomp
      @obj_metadata = { 'diff' => diff, 'reference' => reference }
    end
  end

  def obj_path
    Fits_metadata::create_path(filename: @filename, directory: @directory)
  end
end

  