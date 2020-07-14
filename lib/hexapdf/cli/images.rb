# -*- encoding: utf-8; frozen_string_literal: true -*-
#
#--
# This file is part of HexaPDF.
#
# HexaPDF - A Versatile PDF Creation and Manipulation Library For Ruby
# Copyright (C) 2014-2020 Thomas Leitner
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
#
# If the GNU Affero General Public License doesn't fit your need,
# commercial licenses are available at <https://gettalong.at/hexapdf/>.
#++

require 'set'
require 'hexapdf/cli/command'

module HexaPDF
  module CLI

    # Lists or extracts images from a PDF file.
    #
    # See: HexaPDF::Type::Image
    class Images < Command

      # Extracts the PPI (pixel per inch) information for each image of a content stream.
      class ImageLocationProcessor < HexaPDF::Content::Processor

        # The mapping of XObject name to [x_ppi, y_ppi].
        attr_reader :result

        # Initialize the processor with the names of the images for which the PPI should be
        # determined.
        def initialize(names, user_unit)
          super()
          @names = names
          @user_unit = user_unit
          @result = {}
        end

        # Determine the PPI in x- and y-directions of the specified images.
        def paint_xobject(name)
          super
          return unless @names.delete(name)
          xobject = resources.xobject(name)
          return unless xobject[:Subtype] == :Image

          w, h = xobject.width, xobject.height
          llx, lly = graphics_state.ctm.evaluate(0, 0).map {|i| i * @user_unit }
          lrx, lry = graphics_state.ctm.evaluate(1, 0).map {|i| i * @user_unit }
          ulx, uly = graphics_state.ctm.evaluate(0, 1).map {|i| i * @user_unit }

          x_ppi = 72.0 * w / Math.sqrt((lrx - llx)**2 + (lry - lly)**2)
          y_ppi = 72.0 * h / Math.sqrt((ulx - llx)**2 + (uly - lly)**2)
          @result[name] = [x_ppi.round, y_ppi.round]
          raise StopIteration if @names.empty?
        end

      end

      def initialize #:nodoc:
        super('images', takes_commands: false)
        short_desc("List or extract images from a PDF file")
        long_desc(<<~EOF)
          If the option --extract is not given, the available images are listed with their index and
          additional information, sorted by page number. The --extract option can then be used to
          extract one or more images, saving them to files called `prefix-n.ext` where the prefix
          can be set via --prefix, n is the index and ext is either png, jpg or jpx.
        EOF

        options.on("--extract [A,B,C,...]", "-e [A,B,C,...]", Array,
                   "The indices of the images that should be extracted. Use 0 or no argument to " \
                     "extract all images.") do |indices|
          @indices = (indices ? indices.map(&:to_i) : [0])
        end
        options.on("--prefix PREFIX", String,
                   "The prefix to use when saving images. May include directories. Default: " \
                     "image.") do |prefix|
          @prefix = prefix
        end
        options.on("--[no-]search", "-s", "Search the whole PDF instead of the " \
                   "standard locations (default: false)") do |search|
          @search = search
        end
        options.on("--password PASSWORD", "-p", String,
                   "The password for decryption. Use - for reading from standard input.") do |pwd|
          @password = (pwd == '-' ? read_password : pwd)
        end

        @indices = []
        @prefix = 'image'
        @password = nil
        @search = false
      end

      def execute(pdf) #:nodoc:
        with_document(pdf, password: @password) do |doc|
          if @indices.empty?
            list_images(doc)
          else
            extract_images(doc)
          end
        end
      end

      private

      # Outputs a table with the images of the PDF document.
      def list_images(doc)
        printf("%5s %5s %9s %6s %6s %5s %4s %3s %5s %5s %6s %5s %8s\n",
               "index", "page", "oid", "width", "height", "color", "comp", "bpc",
               "x-ppi", "y-ppi", "size", "type", "writable")
        puts("-" * 77)
        each_image(doc) do |image, index, pindex, (x_ppi, y_ppi)|
          info = image.info
          size = human_readable_file_size(image[:Length] + image[:SMask]&.[](:Length).to_i)
          printf("%5i %5s %9s %6i %6i %5s %4i %3i %5s %5s %6s %5s %8s\n",
                 index, pindex || '-', "#{image.oid},#{image.gen}", info.width, info.height,
                 info.color_space, info.components, info.bits_per_component, x_ppi, y_ppi,
                 size, info.type, info.writable)
        end
      end

      # Extracts the images with the given indices.
      def extract_images(doc)
        done = Set.new
        each_image(doc) do |image, index, _|
          next unless (@indices.include?(index) || @indices.include?(0)) && !done.include?(index)
          info = image.info
          if info.writable
            path = "#{@prefix}-#{index}.#{image.info.extension}"
            maybe_raise_on_existing_file(path)
            puts "Extracting #{path}..." if command_parser.verbosity_info?
            image.write(path)
            done << index
          elsif command_parser.verbosity_warning?
            $stderr.puts "Warning (image #{index}): PDF image format not supported for writing"
          end
        end
      end

      # Iterates over all images.
      def each_image(doc) # :yields: obj, index, page_index
        index = 1
        seen = {}

        doc.pages.each_with_index do |page, pindex|
          image_names = []
          xobjects = page.resources[:XObject]

          xobjects&.each&.map do |name, xobject|
            image_names << name if xobject[:Subtype] == :Image && !xobject[:ImageMask]
          end

          processor = ImageLocationProcessor.new(image_names, page[:UserUnit] || 1)
          page.process_contents(processor)
          processor.result.each do |name, ppi|
            xobject = xobjects[name]
            if seen[xobject]
              yield(xobject, seen[xobject], pindex + 1, ppi)
            else
              yield(xobject, index, pindex + 1, ppi)
              seen[xobject] = index
              index += 1
            end
          end
        end

        if @search
          doc.images.each do |image|
            next if seen[image]
            yield(image, index, nil, nil)
            index += 1
          end
        end
      end

      # Returns the human readable file size.
      def human_readable_file_size(size)
        case size
        when 0..9999 then "#{size}B"
        when 10_000..999_999 then "#{(size / 1024.to_f).round(1)}K"
        else "#{(size.to_f / 1024 / 1024).round(1)}M"
        end
      end

    end

  end
end
