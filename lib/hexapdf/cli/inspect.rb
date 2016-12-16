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

require 'hexapdf/cli/command'

module HexaPDF
  module CLI

    # Shows the internal structure of a PDF file.
    class Inspect < Command

      def initialize #:nodoc:
        super('inspect', takes_commands: false)
        short_desc("Dig into the internal structure of a PDF file")
        long_desc(<<-EOF.gsub!(/^ */, ''))
          Inspects a PDF file for debugging or testing purposes. This command is useful when one
          needs to inspect the internal object structure or a stream of a PDF file. A PDF object is
          always shown in the PDF syntax.

          If no option is given, the main PDF object, the catalog, is shown. Otherwise the various,
          mutually exclusive display options define the shown content. If multiple such options are
          specified only the last is respected.
        EOF

        options.on("-t", "--trailer", "Show the trailer dictionary.") do
          @exec = :trailer
        end
        options.on("-c", "--page-count", "Print the number of pages.") do
          @exec = :page_count
        end
        options.on("--pages [PAGES]", "Show the pages with their object and generation numbers " \
                   "and their associated content streams. If the optional argument PAGES is " \
                   "specified, only the specified pages are listed.") do |range|
          @exec = :pages
          @param = range || '1-e'
        end
        options.on("-o", "--object OID[,GEN]", "Show the object with the given object and " \
                   "generation numbers. The generation number defaults to 0 if not given.") do |str|
          @exec = :object
          @param = str
        end
        options.on("-s", "--stream OID[,GEN]", "Show the filtered stream data (add --raw to get " \
                   "the raw stream data) of the object with the given object and generation " \
                   "numbers. The generation number defaults to 0 if not given.") do |str|
          @exec = :stream
          @param = str
          @raw = (@raw ? @raw : false)
        end
        options.on("--raw", "Modifies --stream to show the raw stream data instead of the " \
                   "filtered one.") do
          @raw = true
        end

        options.separator("")
        options.on("--password PASSWORD", "-p", String,
                   "The password for decryption. Use - for reading from standard input.") do |pwd|
          @password = (pwd == '-' ? read_password : pwd)
        end

        @password = nil
        @exec = :catalog
        @param = nil
        @raw = nil
      end

      def execute(file) #:nodoc:
        HexaPDF::Document.open(file, decryption_opts: {password: @password}) do |doc|
          send("do_#{@exec}", doc)
        end
      rescue HexaPDF::Error => e
        $stderr.puts "Error while processing the PDF file: #{e.message}"
        exit(1)
      end

      private

      def do_catalog(doc) #:nodoc:
        puts HexaPDF::Serializer.new.serialize(doc.catalog)
      end

      def do_trailer(doc) #:nodoc:
        puts HexaPDF::Serializer.new.serialize(doc.trailer)
      end

      def do_page_count(doc) #:nodoc:
        puts doc.pages.count
      end

      def do_pages(doc) #:nodoc:
        pages = parse_pages_specification(@param, doc.pages.count)
        pages.each do |index, _|
          page = doc.pages[index]
          str = "page #{index + 1} (#{page.oid},#{page.gen}): "
          str << Array(page[:Contents]).map {|c| "#{c.oid},#{c.gen}"}.join(" ")
          puts str
        end
      end

      def do_object(doc) #:nodoc:
        object = doc.object(pdf_reference_from_string(@param))
        return unless object
        $stderr.puts("Note: Object also has stream data") if object.data.stream
        puts HexaPDF::Serializer.new.serialize(object.value)
      end

      def do_stream(doc) #:nodoc:
        object = doc.object(pdf_reference_from_string(@param))
        if object.kind_of?(HexaPDF::Stream)
          source = (@raw ? object.stream_source : object.stream_decoder)
          while source.alive? && (data = source.resume)
            $stdout.write(data)
          end
        else
          $stderr.puts("Note: Object has no stream data")
        end
      end

      # Parses the given string of the format "oid[,gen]" and returns a PDF reference object.
      def pdf_reference_from_string(str)
        oid, gen = str.split(",").map(&:to_i)
        HexaPDF::Reference.new(oid, gen || 0)
      end

    end

  end
end
