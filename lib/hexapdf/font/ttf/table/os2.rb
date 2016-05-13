# -*- encoding: utf-8 -*-

require 'hexapdf/font/ttf/table'

module HexaPDF
  module Font
    module TTF
      class Table

        # The 'OS/2' table contains information required by Windows.
        #
        # Some attributes may be +nil+ when read from a file depending on the version of the table.
        #
        # See: https://developer.apple.com/fonts/TrueType-Reference-Manual/RM06/Chap6OS2.html
        class OS2 < Table

          # The version of the table.
          attr_accessor :version

          # AVerage weighted advance width of lower case letters and space.
          attr_accessor :x_avg_char_width

          # Visual weight of stroke in glyphs.
          attr_accessor :weight_class

          # Relative change from the normal aspect ratio (width/height).
          attr_accessor :width_class

          # Characteristics and properties of this font.
          attr_accessor :type

          # Recommended horizontal size in pixels for subscripts
          attr_accessor :subscript_x_size

          # Recommended vertical size in pixels for subscripts
          attr_accessor :subscript_y_size

          # Recommended horizontal offset for subscripts.
          attr_accessor :subscript_x_offset

          # Recommended vertical offset from the baseline for subscripts.
          attr_accessor :subscript_y_offset

          # Recommended horizontal size in pixels for superscripts
          attr_accessor :superscript_x_size

          # Recommended vertical size in pixels for superscripts
          attr_accessor :superscript_y_size

          # Recommended horizontal offset for superscripts.
          attr_accessor :superscript_x_offset

          # Recommended vertical offset from the baseline for superscripts.
          attr_accessor :superscript_y_offset

          # Width of the strikeout stroke.
          attr_accessor :strikeout_size

          # Position of the strikeout stroke relative to the baseline.
          attr_accessor :strikeout_position

          # Classification of the font-family design.
          attr_accessor :family_class

          # Describes the visual characteristics of the given typeface.
          attr_accessor :panose

          # Describes the Unicode ranges covered by the font.
          attr_accessor :char_range

          # The four character identifier of the font vendor.
          attr_accessor :vendor_id

          # Information concerning the nature of the font patterns.
          attr_accessor :selection

          # The minimum Unicode index in this font.
          attr_accessor :first_char_index

          # The maximum Unicode index in this font.
          attr_accessor :last_char_index

          # The typographic ascender. May not be the same as the ascender in the 'hhea' table.
          attr_accessor :typo_ascender

          # The typographic descender. May not be the same as the ascender in the 'hhea' table.
          attr_accessor :typo_descender

          # The typographic line gap. May not be the same as the ascender in the 'hhea' table.
          attr_accessor :typo_line_gap

          # The ascender metric for Windows.
          attr_accessor :win_ascent

          # The descender metric for Windows.
          attr_accessor :win_descent

          # The code page character range.
          attr_accessor :code_page_range

          # The distance between the baseline and the approximate height of non-ascending lowercase
          # letters.
          attr_accessor :x_height

          # The distance between the baseline and the approximate height of uppercase letters.
          attr_accessor :cap_height

          # The default character displayed by Windows to represent an unsupported character.
          attr_accessor :default_char

          # The break character used by Windows.
          attr_accessor :break_char

          # The maximum length of an OpenType context for any feature in this font.
          attr_accessor :max_context

          # The lowest size at which the font starts to be used.
          attr_accessor :lower_point_size

          # The highest size at which the font starts to be used.
          attr_accessor :upper_point_size

          private

          def parse_table #:nodoc:
            @version, @x_avg_char_width, @weight_class, @width_class, @type, @subscript_x_size,
              @subscript_y_size, @subscript_x_offset, @subscript_y_offset, @superscript_x_size,
              @superscript_y_size, @superscript_x_offset, @superscript_y_offset, @strikeout_size,
              @strikeout_position, @family_class, @panose =
              read_formatted(42, 'ns>n2s>12a10')

            @char_range, temp = read_formatted(16, 'Q>2')
            @char_range = @char_range << 64 & temp

            @vendor_id, @selection,
              @first_char_index, @last_char_index, @typo_ascender, @typo_descender, @typo_line_gap,
              @win_ascent, @win_descent, @code_page_range, @x_height, @cap_height, @default_char,
              @break_char, @max_context, @lower_point_size, @upper_point_size =
              read_formatted(directory_entry.length - 58, 'a4n3s>3n2Q>s>2n5')
          end

          def load_default #:nodoc:
            @version = 5
            @panose = ''.b
            @vendor_id = '    '.b
            @x_avg_char_width= @weight_class= @width_class= @type= @subscript_x_size=
              @subscript_y_size= @subscript_x_offset= @subscript_y_offset= @superscript_x_size=
              @superscript_y_size= @superscript_x_offset= @superscript_y_offset= @strikeout_size=
              @strikeout_position= @family_class= @char_range= @selection= @first_char_index=
              @last_char_index= @typo_ascender= @typo_descender= @typo_line_gap= @win_ascent=
              @win_descent= @code_page_range= @x_height= @cap_height= @default_char= @break_char=
              @max_context= @lower_point_size= @upper_point_size = 0
          end

        end

      end
    end
  end
end
