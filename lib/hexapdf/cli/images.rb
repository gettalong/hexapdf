# -*- encoding: utf-8; frozen_string_literal: true -*-
#
#--
# This file is part of HexaPDF.
#
# HexaPDF - A Versatile PDF Creation and Manipulation Library For Ruby
# Copyright (C) 2014-2018 Thomas Leitner
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

require 'set'
require 'hexapdf/cli/command'

module HexaPDF
  module CLI

    # Lists or extracts images from a PDF file.
    #
    # See: HexaPDF::Type::Image
    class Images < Command

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
        printf("%5s %5s %9s %6s %6s %5s %4s %3s %5s %8s\n",
               "index", "page", "oid", "width", "height", "color", "comp", "bpc", "type",
               "writable")
        puts("-" * 65)
        each_image(doc) do |image, index, pindex|
          info = image.info
          printf("%5i %5s %9s %6i %6i %5s %4i %3i %5s %8s\n",
                 index, pindex || '-', "#{image.oid},#{image.gen}", info.width, info.height,
                 info.color_space, info.components, info.bits_per_component, info.type,
                 info.writable)
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
          page.resources[:XObject]&.each do |_name, xobject|
            if seen[xobject]
              yield(xobject, seen[xobject], pindex + 1)
            elsif xobject[:Subtype] == :Image && !xobject[:ImageMask]
              yield(xobject, index, pindex + 1)
              seen[xobject] = index
              index += 1
            end
          end
        end

        if @search
          doc.images.each do |image|
            next if seen[image]
            yield(image, index, nil)
            index += 1
          end
        end
      end

    end

  end
end
