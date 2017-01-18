# -*- encoding: utf-8 -*-
#
#--
# This file is part of HexaPDF.
#
# HexaPDF - A Versatile PDF Creation and Manipulation Library For Ruby
# Copyright (C) 2016 Thomas Leitner
#
# HexaPDF is free software: you can redistribute it and/or modify it
# under the terms of the GNU Affero General Public License version 3 as
# published by the Free Software Foundation with the addition of the
# following permission added to Section 15 as permitted in Section 7(a):
# FOR ANY PART OF THE COVERED WORK IN WHICH THE COPYRIGHT IS OWNED BY
# THOMAS LEITNER, THOMAS LEITNER DISCLAIMS THE WARRANTY OF NON
# INFRINGEMENT OF THIRD PARTY RIGHTS.
#
# HexaPDF is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
# FITNESS FOR A PARTICULAR PURPOSE. See the GNU Affero General Public
# License for more details.
#
# You should have received a copy of the GNU Affero General Public License
# along with HexaPDF. If not, see <http://www.gnu.org/licenses/>.
#
# The interactive user interfaces in modified source and object code
# versions of HexaPDF must display Appropriate Legal Notices, as required
# under Section 5 of the GNU Affero General Public License version 3.
#
# In accordance with Section 7(b) of the GNU Affero General Public
# License, a covered work must retain the producer line in every PDF that
# is created or manipulated using HexaPDF.
#++

require 'zlib'
require 'hexapdf/error'
require 'hexapdf/stream'
require 'hexapdf/image_loader'

module HexaPDF
  module Type

    # Represents an image XObject of a PDF document.
    #
    # See: PDF1.7 s8.8
    class Image < Stream

      define_field :Type,             type: Symbol,          default: :XObject
      define_field :Subtype,          type: Symbol,          required: true, default: :Image
      define_field :Width,            type: Integer,         required: true
      define_field :Height,           type: Integer,         required: true
      define_field :ColorSpace,       type: [Symbol, Array]
      define_field :BitsPerComponent, type: Integer
      define_field :Intent,           type: Symbol,          version: '1.1'
      define_field :ImageMask,        type: Boolean,         default: false
      define_field :Mask,             type: [Stream, Array], version: '1.3'
      define_field :Decode,           type: Array
      define_field :Interpolate,      type: Boolean,         default: false
      define_field :Alternates,       type: Array,           version: '1.3'
      define_field :SMask,            type: Stream,          version: '1.4'
      define_field :SMaskInData,      type: Integer,         version: '1.5'
      define_field :StructParent,     type: Integer,         version: '1.3'
      define_field :ID,               type: PDFByteString,   version: '1.3'
      define_field :OPI,              type: Dictionary,      version: '1.2'
      define_field :Metadata,         type: Stream,          version: '1.4'
      define_field :OC,               type: Dictionary,      version: '1.5'

      # Returns the source path that was used when creating the image object.
      #
      # This value is only set when the image object was created by using the image loading
      # facility and not when the image is part of a loaded PDF file.
      attr_accessor :source_path

      # :call-seq:
      #   image.write(basename)
      #   image.write(io)
      #
      # Saves this image XObject to the file with the given name and appends the correct extension
      # (if the name already contains this extension, the name is used as is), or the given IO
      # object.
      #
      # Raises an error if the image format is not supported.
      #
      # These are the supported filters and their output format and extension:
      #
      # DCTDecode:: Saved as a JPEG file with the extension '.jpg'
      # JPXDecode:: Saved as a JPEG2000 file with the extension '.jpx'
      # FlateDecode or no filter:: Saved as a PNG file with the extension '.png'
      def write(name_or_io)
        filter, rest = *self[:Filter]
        if rest || ![:FlateDecode, :DCTDecode, :JPXDecode, nil].include?(filter)
          raise HexaPDF::Error, "Unsupported PDF image format (reason: filter #{self[:Filter]})"
        end

        io = if name_or_io.kind_of?(String)
               ext = case filter
                     when :DCTDecode then 'jpg'
                     when :JPXDecode then 'jpx'
                     else 'png'
                     end
               File.open(name_or_io.sub(/\.#{ext}\z/, '') + "." + ext, "wb")
             else
               name_or_io
             end

        if filter == :DCTDecode || filter == :JPXDecode
          source = stream_source
          while source.alive? && (chunk = source.resume)
            io << chunk
          end
        else
          write_png(io)
        end
      ensure
        io.close if io && name_or_io.kind_of?(String)
      end

      private

      # Writes the image as PNG to the given IO stream.
      def write_png(io)
        filter, = *self[:Filter]
        io << ImageLoader::PNG::MAGIC_FILE_MARKER

        width = self[:Width]
        height = self[:Height]
        bpc = self[:BitsPerComponent]

        colorspace, = *self[:ColorSpace]
        if colorspace == :DeviceRGB || colorspace == :CalRGB
          color_type = ImageLoader::PNG::TRUECOLOR
        elsif colorspace == :DeviceGray || colorspace == :CalGray
          color_type = ImageLoader::PNG::GREYSCALE
        elsif colorspace == :Indexed
          color_type = ImageLoader::PNG::INDEXED
          colorspace, = *document.deref(self[:ColorSpace][1])
          if colorspace == :DeviceRGB || colorspace == :CalRGB
            colorspace = :rgb
          elsif colorspace == :DeviceGray || colorspace == :CalGray
            colorspace = :gray
          else
            raise HexaPDF::Error, "Unsupported PDF image format (reason: indexed colorspace)"
          end
        else
          raise HexaPDF::Error, "Unsupported PDF image format (reason: colorspace)"
        end

        io << png_chunk('IHDR', [width, height, bpc, color_type, 0, 0, 0].pack('N2C5'))

        if key?(:Intent)
          # PNG s11.3.3.5
          intent = ImageLoader::PNG::RENDERING_INTENT_MAP.rassoc(self[:Intent]).first
          io << png_chunk('sRGB', intent.chr) <<
            png_chunk('gAMA', [45455].pack('N')) <<
            png_chunk('cHRM', [31270, 32900, 64000, 33000, 30000, 60000, 15000, 6000].pack('N8'))
        end

        if color_type == ImageLoader::PNG::INDEXED
          palette_data = document.deref(self[:ColorSpace][3])
          palette_data = palette_data.stream unless palette_data.kind_of?(String)
          palette = ''.b
          if colorspace == :rgb
            palette = palette_data[0, palette_data.length - palette_data.length % 3]
          else
            palette_data.each_byte {|byte| palette << byte << byte << byte}
          end
          io << png_chunk('PLTE', palette)
        end

        if self[:Mask].kind_of?(Array) && self[:Mask].each_slice(2).all? {|a, b| a == b} &&
            (color_type == ImageLoader::PNG::TRUECOLOR || color_type == ImageLoader::PNG::GREYSCALE)
          io << png_chunk('tRNS', self[:Mask].each_slice(2).map {|a, _| a}.pack('n*'))
        end

        if filter == :FlateDecode && self[:DecodeParms] && self[:DecodeParms][:Predictor].to_i >= 10
          data = stream_source
        else
          flate_decode = GlobalConfiguration.constantize('filter.map', :FlateDecode)
          data = flate_decode.encoder(stream_decoder, Predictor: 15, Colors: 1,
                                      BitsPerComponent: bpc, Columns: width)
        end
        io << png_chunk('IDAT', Filter.string_from_source(data))

        io << png_chunk('IEND', '')
      end

      # Returns the binary representation of the PNG chunk for the given chunk type and data.
      def png_chunk(type, data = nil)
        [data.to_s.length].pack("N") << type << data.to_s <<
          [Zlib.crc32(data, Zlib.crc32(type))].pack("N")
      end

    end

  end
end
