require 'hashie'
require 'rubycue'

module CueSnap
  class Splitter
    # Public: Loads an mp3 and a RubyCue cuesheet.
    #
    # mp3_file  - String file path to an mp3 file.
    # cue_file  - The path to a cuesheet for the target cue file (default: the
    #               name of the mp3, with .cue added).
    # options   - Hash of options.
    #             no_numbers - No number prefix for tracks.
    #             output_folder - The output folder to use (default: the name
    #               of the mp3).
    #
    # Returns the initalized object.
    def initialize(mp3_file, cue_file = nil, options = {})
      @mp3_file = mp3_file
      if cue_file and cue_file.strip != ''
        @cue_file = cue_file
      else
        @cue_file = File.expand_path("#{mp3_filename}.cue", File.dirname(@mp3_file))
      end

      @options = Hashie::Mash.new options
      @output_folder = @options.output_folder
      @output_folder ||= mp3_filename
    end

    # Internal: Parses the cue file using RubyCue and sets the @cuesheet
    # variable.
    #
    # Returns nothing.
    def parse_cue_file
      file_contents = File.read @cue_file

      # Try to fix unicode problems
      # use iconv if on Ruby 1.8
      # From: bit.ly/bGmrCnCOPY
      require 'iconv' unless String.method_defined?(:encode)
      if String.method_defined?(:encode)
        file_contents.encode!('UTF-16', 'UTF-8', :invalid => :replace, :replace => '')
        file_contents.encode!('UTF-8', 'UTF-16')
      else
        ic = Iconv.new('UTF-8', 'UTF-8//IGNORE')
        file_contents = ic.iconv(file_contents)
      end

      @cuesheet = RubyCue::Cuesheet.new file_contents
      @cuesheet.parse!
    end

    # Public: Splits the mp3 into files based on track_names and saves them to
    # the output folder.
    #
    # Returns nothing.
    def split!
      # Wait until the last second to parse the cue file, in case the user
      # changes it before we split.
      parse_cue_file

      format = "@p - @t"

      song_count_length = (@cuesheet.songs.length + 1).to_s.length
      number_format = "@N#{song_count_length > 1 ? song_count_length : ''}"
      format = "#{number_format} #{format}" unless @options.no_numbers

      # Got to esape the spaces for the shell
      format.gsub!(/\s/, '\\ ')

      command = ['mp3splt',
                 "-d #{output_folder}",
                 "-o #{format}",
                 "-c #@cue_file"]
      command.push '-Q' if @options.quiet
      command.push @mp3_file

      system command.join(' ')
    end

    # Public: The filename for the mp3 file with the .mp3 extension removed.
    def mp3_filename
      File.basename(@mp3_file, '.mp3')
    end

    attr_reader :mp3_file, :cue_file, :output_folder, :options

  end
end
