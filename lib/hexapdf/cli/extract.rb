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

require 'hexapdf/cli'

module HexaPDF
  module CLI

    # Extracts files from a PDF file.
    #
    # See: HexaPDF::Type::EmbeddedFile
    class Extract < CmdParse::Command

      def initialize #:nodoc:
        super('extract', takes_commands: false)
        short_desc("Extract files from a PDF file")
        long_desc(<<-EOF.gsub!(/^ */, ''))
          This command extracts files embedded in a PDF file. If the option --indices is not given,
          the available files are listed with their names and indices. The --indices option can then
          be used to extract one or more files.
        EOF
        options.on("--indices a,b,c", "-i a,b,c,...", Array,
                   "The indices of the files that should be extracted. Use 0 to extract " \
                   "all files.") do |indices|
          @indices = indices.map(&:to_i)
        end
        options.on("--[no-]search", "-s", "Search the whole PDF instead of the " \
                   "standard locations (default: false)") do |search|
          @search = search
        end
        options.on("--password PASSWORD", "-p", String,
                   "The password for decryption. Use - for reading from standard input.") do |pwd|
          @password = (pwd == '-' ? command_parser.read_password : pwd)
        end
        @indices = []
        @password = ''
        @search = false
      end

      def execute(file) #:nodoc:
        HexaPDF::Document.open(file, decryption_opts: {password: @password}) do |doc|
          if @indices.empty?
            list_files(doc)
          else
            extract_files(doc)
          end
        end
      rescue HexaPDF::Error => e
        $stderr.puts "Error while processing the PDF file: #{e.message}"
        exit(1)
      end

      private

      # Outputs the list of files embedded in the given PDF document.
      def list_files(doc)
        each_file(doc) do |obj, index|
          $stdout.write(sprintf("%4i: %s", index + 1, obj.path))
          ef_stream = obj.embedded_file_stream
          if (params = ef_stream[:Params]) && !params.empty?
            data = []
            data << "size: #{params[:Size]}" if params.key?(:Size)
            data << "md5: #{params[:CheckSum].unpack('H*').first}" if params.key?(:CheckSum)
            data << "ctime: #{params[:CreationDate]}" if params.key?(:CreationDate)
            data << "mtime: #{params[:ModDate]}" if params.key?(:ModDate)
            $stdout.write(" (#{data.join(', ')})")
          end
          $stdout.puts
          $stdout.puts("      #{obj[:Desc]}") if obj[:Desc] && !obj[:Desc].empty?
        end
      end

      # Extracts the files with the given indices.
      def extract_files(doc)
        each_file(doc) do |obj, index|
          next unless @indices.include?(index + 1) || @indices.include?(0)
          if File.exist?(obj.path)
            raise HexaPDF::Error, "Output file #{obj.path} already exists, not overwriting"
          end
          puts "Extracting #{obj.path}..."
          File.open(obj.path, 'wb') do |file|
            fiber = obj.embedded_file_stream.stream_decoder
            while fiber.alive? && (data = fiber.resume)
              file << data
            end
          end
        end
      end

      # Iterates over all embedded files.
      def each_file(doc, &block) # :yields: obj, index
        doc.files.each(search: @search).select(&:embedded_file?).each_with_index(&block)
      end

    end

  end
end
