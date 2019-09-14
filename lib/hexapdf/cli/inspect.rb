# -*- encoding: utf-8; frozen_string_literal: true -*-
#
#--
# This file is part of HexaPDF.
#
# HexaPDF - A Versatile PDF Creation and Manipulation Library For Ruby
# Copyright (C) 2014-2019 Thomas Leitner
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

require 'hexapdf/cli/command'

module HexaPDF
  module CLI

    # Shows the internal structure of a PDF file.
    class Inspect < Command

      def initialize #:nodoc:
        super('inspect', takes_commands: false)
        short_desc("Dig into the internal structure of a PDF file")
        long_desc(<<~EOF)
          Inspects a PDF file for debugging or testing purposes. This command is useful when one
          needs to inspect the internal object structure or a stream of a PDF file. A PDF object is
          always shown in the PDF syntax.

          If no option is given, the interactive mode is started. Otherwise the various, mutually
          exclusive display options define the shown content. If multiple such options are specified
          only the last is respected.
        EOF

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
        end
        options.on("--raw", "Modifies --stream to show the raw stream data instead of the " \
                   "filtered one.") do
          @raw = true
        end
        options.on("-c", "--page-count", "Print the number of pages.") do
          @exec = :page_count
        end
        options.on("--catalog", "Show the PDF catalog dictionary.") do
          @exec = :catalog
        end
        options.on("--trailer", "Show the PDF trailer dictionary.") do
          @exec = :trailer
        end
        options.on("--pages [PAGES]", "Show the pages with their object and generation numbers " \
                   "and their associated content streams. If the optional argument PAGES is " \
                   "specified, only the specified pages are listed.") do |range|
          @exec = :pages
          @param = range || '1-e'
        end
        options.on("--structure", "Show the structure of the PDF file.") do
          @exec = :structure
        end

        options.separator("")
        options.on("--password PASSWORD", "-p", String,
                   "The password for decryption. Use - for reading from standard input.") do |pwd|
          @password = (pwd == '-' ? read_password : pwd)
        end

        @password = nil
        @exec = :interactive
        @param = nil
        @raw = nil
        @serializer = HexaPDF::Serializer.new
      end

      def execute(file) #:nodoc:
        with_document(file, password: @password) do |doc|
          @doc = doc
          send("do_#{@exec}")
        end
      end

      private

      def do_interactive #:nodoc:
        while true
          print "cmd> "
          input = $stdin.gets
          (puts; break) unless input

          command, *args = input.scan(/(["'])(.+?)\1|(\S+)/).map {|a| a[1] || a[2] }
          case command
          when /^\d+(,\d+)?$/, 'o', 'object'
            arg = (command.start_with?('o') ? args.first : command)
            obj = pdf_object_from_string_reference(arg) rescue puts($!.message)
            serialize(obj.value, recursive: false) if obj
          when 'r', 'recursive'
            obj = pdf_object_from_string_reference(args.first) rescue puts($!.message)
            serialize(obj.value, recursive: true) if obj
          when 's', 'stream'
            if (pdf_object_from_string_reference(args.first) rescue puts($!.message))
              @param = args.first
              do_stream
            end
          when 'c', 'catalog'
            do_catalog
          when 't', 'trailer'
            do_trailer
          when 'p', 'pages'
            @param = args.first || '1-e'
            do_pages rescue puts "Error: Invalid page range argument"
          when 'search'
            if args.empty?
              puts "Error: Missing argument regexp"
              next
            end
            re = Regexp.new(args.first, Regexp::IGNORECASE)
            @doc.each do |object|
              if (object.value.kind_of?(Hash) &&
                  object.value.any? {|k, v| k.to_s.match?(re) || v.to_s.match?(re) }) ||
                  (object.value.kind_of?(Array) &&
                   object.value.any? {|i| i.to_s.match?(re) }) ||
                  object.value.to_s.match?(re)
                puts "#{object.oid} #{object.gen} obj"
                serialize(object.value, recursive: false)
                puts "endobj"
              end
            end
          when 'q', 'quit'
            break
          when 'h', 'help'
            puts <<~HELP
              OID[,GEN] | o[bject] OID[,GEN] - Print object
              r[ecursive] OID[,GEN]          - Print object recursively
              s[tream] OID[,GEN]             - Print filtered stream
              c[atalog]                      - Print the catalog dictionary
              t[railer]                      - Print the trailer dictionary
              p[ages] [RANGE]                - Print information about pages
              search REGEXP                  - Print objects matching the pattern
              h[elp]                         - Show this help
              q[uit]                         - Quit
            HELP
          else
            if command
              puts "Error: Unknown command '#{command}' - enter 'help' for a list of commands"
            end
          end
        end
      end

      def do_structure #:nodoc:
        serialize(@doc.trailer.value)
      end

      def do_catalog #:nodoc:
        serialize(@doc.catalog.value, recursive: false)
      end

      def do_trailer #:nodoc:
        serialize(@doc.trailer.value, recursive: false)
      end

      def do_page_count #:nodoc:
        puts @doc.pages.count
      end

      def do_pages #:nodoc:
        pages = parse_pages_specification(@param, @doc.pages.count)
        page_list = @doc.pages.to_a
        pages.each do |index, _|
          page = page_list[index]
          str = +"page #{index + 1} (#{page.oid},#{page.gen}): "
          str << Array(page[:Contents]).map {|c| "#{c.oid},#{c.gen}" }.join(" ")
          puts str
        end
      end

      def do_object #:nodoc:
        object = @doc.object(pdf_reference_from_string(@param))
        return unless object
        if object.data.stream && command_parser.verbosity_info?
          $stderr.puts("Note: Object also has stream data")
        end
        serialize(object.value, recursive: false)
      end

      def do_stream #:nodoc:
        object = @doc.object(pdf_reference_from_string(@param))
        if object.kind_of?(HexaPDF::Stream)
          source = (@raw ? object.stream_source : object.stream_decoder)
          while source.alive? && (data = source.resume)
            $stdout.write(data)
          end
        elsif command_parser.verbosity_info?
          $stderr.puts("Note: Object has no stream data")
        end
      end

      # Resolves the PDF object from the given string reference and returns it.
      def pdf_object_from_string_reference(str)
        if str.nil?
          raise "Error: Missing argument object identifier OID[,GEN]"
        elsif !str.match?(/^\d+(,\d+)?$/)
          raise "Error: Invalid argument: Must be of form OID[,GEN]"
        elsif !(obj = @doc.object(pdf_reference_from_string(str)))
          raise "Error: No object with the given object identifier found"
        else
          obj
        end
      end

      # Parses the given string of the format "oid[,gen]" and returns a PDF reference object.
      def pdf_reference_from_string(str)
        oid, gen = str.split(",").map(&:to_i)
        HexaPDF::Reference.new(oid, gen || 0)
      end

      # Prints the serialized value to the standard output. If +recursive+ is +true+, then the whole
      # object tree is printed, with object references to already printed objects replaced by
      # specially generated PDF references.
      def serialize(val, recursive: true, seen: {}, indent: 0) #:nodoc:
        case val
        when Hash
          puts "<<"
          (recursive ? val.sort : val).each do |k, v|
            next if v.nil? || (v.respond_to?(:null?) && v.null?)
            print '  ' * (indent + 1) + @serializer.serialize_symbol(k) + " "
            serialize(v, recursive: recursive, seen: seen, indent: indent + 1)
            puts
          end
          print "#{'  ' * indent}>>"
        when Array
          print "["
          val.each do |v|
            serialize(v, recursive: recursive, seen: seen, indent: indent)
            print " "
          end
          print "]"
        when HexaPDF::Reference
          serialize(@doc.object(val), recursive: recursive, seen: seen, indent: indent)
        when HexaPDF::Object
          if !recursive
            if val.indirect?
              print "#{val.oid} #{val.gen} R"
            else
              serialize(val.value, recursive: recursive, seen: seen, indent: indent)
            end
          elsif val.nil? || seen.key?(val.data)
            print "{ref #{seen[val.data]}}"
          else
            seen[val.data] = (val.type == :Page ? "page #{val.index + 1}" : seen.length + 1)
            print "{obj #{seen[val.data]}} "
            serialize(val.value, recursive: recursive, seen: seen, indent: indent)
          end
        else
          print @serializer.serialize(val)
        end
        puts if indent == 0
      end

    end

  end
end
