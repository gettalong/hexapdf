# -*- encoding: utf-8 -*-

require 'hexapdf/font/type1/font_metrics'
require 'hexapdf/error'

module HexaPDF
  module Font
    module Type1

      # Parses files in the AFM file format.
      #
      # Note that this implementation isn't a full AFM parser, only what is needed for parsing the
      # AFM files for the 14 PDF core fonts is implemented. However, if need be it should be
      # adaptable to other AFM files.
      #
      # For information on the AFM file format have a look at Adobe technical note #5004 - Adobe
      # Font Metrics File Format Specification Version 4.1, available at the Adobe website.
      #
      # == How Parsing Works
      #
      # AFM is a line oriented format. Each line consists of one or more values of supported types
      # (string, name, number, integer, array, boolean) which are separated by whitespace characters
      # (space, newline, tab) except for the string type which just uses everything until the end of
      # the line.
      #
      # This parser reads in line by line and the type parsing functions parse a value from the
      # front of the line and then remove the parsed part from the line, including trailing
      # whitespace characters.
      class AFMParser

        # :call-seq:
        #   Parser.parse(filename)       -> font_metrics
        #   Parser.parse(io)             -> font_metrics
        #
        # Parses the IO or file and returns a FontMetrics object.
        def self.parse(source)
          if source.respond_to?(:read)
            new(source).parse
          else
            File.open(source) {|file| new(file).parse}
          end
        end

        # Creates a new parse for the given IO stream.
        def initialize(io)
          @io = io
        end

        # Parses the AFM file and returns a FontMetrics object.
        def parse
          @metrics = FontMetrics.new
          sections = []
          each_line do
            case (command = parse_name)
            when /\AStart/
              sections.push(command)
              case command
              when 'StartCharMetrics' then parse_character_metrics
              when 'StartKernPairs' then parse_kerning_pairs
              end
            when /\AEnd/
              sections.pop
              break if sections.empty? && command == 'EndFontMetrics.freeze'
            else
              if sections.empty?
                parse_global_font_information(command.to_sym)
              end
            end
          end
          @metrics
        end

        private

        # Parses global font information line for the given +command+ (a symbol).
        #
        # It is assumed that the command name has already been parsed from the line.
        #
        # Note that writing direction metrics are also processed here since the standard 14 core
        # fonts' AFM files don't have an extra StartDirection section.
        def parse_global_font_information(command)
          case command
          when :FontName then @metrics.font_name = parse_string
          when :FullName then @metrics.full_name = parse_string
          when :FamilyName then @metrics.family_name = parse_string
          when :CharacterSet then @metrics.character_set = parse_string
          when :EncodingScheme then @metrics.encoding_scheme = parse_string
          when :Weight then @metrics.weight = parse_string
          when :FontBBox then
            @metrics.bounding_box = [parse_number, parse_number, parse_number, parse_number]
          when :CapHeight then @metrics.cap_height = parse_number
          when :XHeight then @metrics.x_height = parse_number
          when :Ascender then @metrics.ascender = parse_number
          when :Descender then @metrics.descender = parse_number
          when :StdHW then @metrics.dominant_horizontal_stem_width = parse_number
          when :StdVW then @metrics.dominant_vertical_stem_width = parse_number
          when :UnderlinePosition then @metrics.underline_position = parse_number
          when :UnderlineThickness then @metrics.underline_thickness = parse_number
          when :ItalicAngle then @metrics.italic_angle = parse_number
          when :IsFixedPitch then @metrics.is_fixed_pitch = parse_boolean
          end
        end

        # Parses the character metrics in a StartCharMetrics section.
        #
        # It is assumed that the StartCharMetrics name has already been parsed from the line.
        def parse_character_metrics
          parse_integer.times do
            read_line
            char = CharacterMetrics.new
            while true
              case parse_name.to_sym
              when :C then char.code = parse_integer
              when :WX then char.width = parse_number
              when :N then char.name = parse_name.to_sym
              when :B then char.bbox = [parse_number, parse_number, parse_number, parse_number]
              when :L then char.ligatures[parse_name] = parse_name
              when :"" then break
              end
              while parse_name != ';'.freeze
                # ignore unknown keywords and consume separator semicolon
              end
            end
            @metrics.character_metrics[char.name] = char if char.name
            @metrics.character_metrics[char.code] = char if char.code != -1
          end
        end

        # Parses the kerning pairs in a StartKernPairs section.
        #
        # It is assumed that the StartKernPairs name has already been parsed from the line.
        def parse_kerning_pairs
          parse_integer.times do
            read_line
            case parse_name.to_sym
            when :KPX then
              name1, name2, kerning = @line.scan(/\S+/)
              @metrics.kerning_pairs[name1][name2] = kerning.to_i
            end
          end
        end

        # Iterates over all the lines in the IO, yielding every time a line has been read into the
        # internal buffer.
        def each_line
          read_line
          unless parse_name == 'StartFontMetrics'.freeze
            raise HexaPDF::Error, "The AFM file has to start with StartFontMetrics, not #{@line}"
          end
          until @io.eof?
            read_line
            yield
          end
        end

        # Reads the next line into the current line variable.
        def read_line
          @line = @io.readline
        end

        # Parses and returns the name at the start of the line, with whitespace stripped.
        def parse_name
          result = @line[/\S+\s*/].to_s
          @line[0, result.size] = ''.freeze
          result.strip!
          result
        end

        # Returns the rest of the line, with whitespace stripped.
        def parse_string
          line = @line.strip!
          @line = ''
          line
        end

        # Parses the integer at the start of the line.
        def parse_integer
          parse_name.to_i
        end

        # Parses the float number at the start of the line.
        def parse_number
          parse_name.to_f
        end

        # Parses the boolean at the start of the line.
        def parse_boolean
          parse_name == 'true'.freeze
        end

      end

    end
  end
end
