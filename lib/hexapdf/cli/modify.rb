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

require 'ostruct'
require 'hexapdf/cli'

module HexaPDF
  module CLI

    # Modifies a PDF file:
    #
    # * Adds pages from other PDF files.
    # * Decrypts or encrypts the resulting output PDF file.
    # * Generates or deletes object and cross-reference streams.
    # * Optimizes the output PDF by merging the revisions of a PDF file and removes unused entries.
    #
    # See: HexaPDF::Task::Optimize
    class Modify < CmdParse::Command

      InputSpec = Struct.new(:file, :pages, :password) #:nodoc:

      def initialize #:nodoc:
        super('modify', takes_commands: false)
        short_desc("Modify a PDF file")
        long_desc(<<-EOF.gsub!(/^ */, ''))
          This command modifies a PDF file. It can be used to select pages that should appear in
          the output file and to add pages from other PDF files. The output file can be
          encrypted/decrypted and optimized in various ways.

          The first input file is the primary file which gets modified, so meta data like file
          information, outlines, etc. are taken from it. Alternatively, it is possible to start
          with an empty PDF file by using --empty. The order of the options specifying the files
          is important as they are used in that order.

          Also note that the --password and --pages options apply to the last preceeding input file.
        EOF

        options.separator("")
        options.separator("Input file(s) related options")
        options.on("-f", "--file FILE", "Input file, can be specified multiple times") do |file|
          @files << InputSpec.new(file, '1-e')
        end
        options.on("-p", "--password PASSWORD", String, "The password for decrypting the last " \
                   "specified input file (use - for reading from standard input)") do |pwd|
          raise OptionParser::InvalidArgument, "(No prior input file specified)" if @files.empty?
          pwd = (pwd == '-' ? command_parser.read_password("#{@files.last.file} password") : pwd)
          @files.last.password = pwd
        end
        options.on("-i", "--pages PAGES", "The pages of the last specified input file that " \
                   "should be used (default: 1-e)") do |pages|
          raise OptionParser::InvalidArgument, "(No prior input file specified)" if @files.empty?
          @files.last.pages = pages
        end
        options.on("-e", "--empty", "Use an empty file as the first input file") do
          @initial_empty = true
        end
        options.on("--[no-]interleave", "Interleave the pages from the input files (default: " \
                   "false)") do |c|
          @interleave = c
        end

        options.separator("")
        options.separator("Output file related options")
        options.on("--embed FILE", String, "Embed the file into the output file (can be used " \
                   "multiple times)") do |file|
          @embed_files << file
        end
        options.on("--[no-]compact", "Delete unnecessary PDF objects (default: yes)") do |c|
          @compact = c
        end
        options.on("--object-streams MODE", [:generate, :preserve, :delete],
                   "Handling of object streams (either generate, preserve or delete; " \
                   "default: preserve)") do |os|
          @object_streams = os
        end
        options.on("--xref-streams MODE", [:generate, :preserve, :delete],
                   "Handling of cross-reference streams (either generate, preserve or delete; " \
                   "default: preserve)") do |x|
          @xref_streams = x
        end
        options.on("--streams MODE", [:compress, :preserve, :uncompress],
                   "Handling of stream data (either compress, preserve or uncompress; default: " \
                   "preserve)") do |streams|
          @streams = streams
        end
        options.on("--[no-]compress-pages", "Recompress page content streams (may take a long " \
                   "time; default: no)") do |c|
          @compress_pages = c
        end
        options.on("--decrypt", "Remove any encryption") do
          @encryption = :remove
        end
        options.on("--encrypt", "Encrypt the output file") do
          @encryption = :add
        end
        options.on("--owner-password PASSWORD", String, "The owner password to be set on the " \
                   "output file (use - for reading from standard input)") do |pwd|
          @encryption = :add
          @enc_owner_pwd = (pwd == '-' ? command_parser.read_password("Owner password") : pwd)
        end
        options.on("--user-password PASSWORD", String, "The user password to be set on the " \
                   "output file (use - for reading from standard input)") do |pwd|
          @encryption = :add
          @enc_user_pwd = (pwd == '-' ? command_parser.read_password("User password") : pwd)
        end
        options.on("--algorithm ALGORITHM", [:aes, :arc4],
                   "The encryption algorithm: aes or arc4 (default: aes)") do |a|
          @encryption = :add
          @enc_algorithm = a
        end
        options.on("--key-length BITS", Integer,
                   "The encryption key length in bits (default: 128)") do |i|
          @encryption = :add
          @enc_key_length = i
        end
        options.on("--force-V4",
                   "Force the use of encryption version 4 if key length=128 and algorithm=arc4") do
          @encryption = :add
          @enc_force_v4 = true
        end
        syms = HexaPDF::Encryption::StandardSecurityHandler::Permissions::SYMBOL_TO_PERMISSION.keys
        options.on("--permissions PERMS", Array,
                   "Comma separated list of permissions to be set on the output file. Possible " \
                   "values: #{syms.join(', ')}") do |perms|
          perms.map! do |perm|
            unless syms.include?(perm.to_sym)
              raise OptionParser::InvalidArgument, "#{perm} (invalid permission name)"
            end
            perm.to_sym
          end
          @encryption = :add
          @enc_permissions = perms
        end

        @files = []
        @initial_empty = false
        @interleave = false

        @embed_files = []
        @compact = true
        @compress_pages = false
        @object_streams = :preserve
        @xref_streams = :preserve
        @streams = :preserve

        @encryption = :preserve
        @enc_user_pwd = @enc_owner_pwd = nil
        @enc_key_length = 128
        @enc_algorithm = :aes
        @enc_force_v4 = false
        @enc_permissions = []
      end

      def execute(output_file) #:nodoc:
        if !@initial_empty && @files.empty?
          error = OptionParser::ParseError.new("At least one --file FILE or --empty is needed")
          error.reason = "Missing argument"
          raise error
        end

        # Create PDF documents for each input file
        cache = {}
        @files.each do |spec|
          cache[spec.file] ||= HexaPDF::Document.new(io: File.open(spec.file),
                                                     decryption_opts: {password: spec.password})
          spec.file = cache[spec.file]
        end

        # Assemble pages
        target = (@initial_empty ? HexaPDF::Document.new : @files.first.file)
        page_tree = target.add(Type: :Pages)
        import_pages(page_tree)
        target.catalog[:Pages] = page_tree

        # Remove potentially imported but unused pages and page tree nodes
        retained = target.pages.each_page.with_object({}) {|page, h| h[page.data] = true}
        retained[target.pages.data] = true
        target.each(current: false) do |obj|
          next unless obj.kind_of?(HexaPDF::Dictionary)
          if (obj.type == :Pages || obj.type == :Page) && !retained.key?(obj.data)
            target.delete(obj)
          end
        end

        # Embed the given files
        @embed_files.each {|file| target.utils.add_file(file, embed: true)}

        # Optimize the PDF file
        target.task(:optimize, compact: @compact, object_streams: @object_streams,
                    xref_streams: @xref_streams, compress_pages: @compress_pages)

        # Update stream filters
        handle_streams(target) unless @streams == :preserve

        # Encrypt, decrypt or do nothing
        if @encryption == :add
          target.encrypt(algorithm: @enc_algorithm, key_length: @enc_key_length,
                         force_V4: @enc_force_v4, permissions: @enc_permissions,
                         owner_password: @enc_owner_pwd, user_password: @enc_user_pwd)
        elsif @encryption == :remove
          target.encrypt(name: nil)
        end

        target.write(output_file)
      rescue HexaPDF::Error => e
        $stderr.puts "Processing error : #{e.message}"
        exit(1)
      end

      def usage_arguments #:nodoc:
        "{--file IN_FILE | --empty} OUT_FILE"
      end

      private

      # Imports the pages of the document as specified with the --pages option to the given page
      # tree.
      def import_pages(page_tree)
        @files.each do |s|
          s.pages = command_parser.parse_pages_specification(s.pages, s.file.pages.page_count)
          s.pages.each do |arr|
            next if arr[1]
            arr[1] = s.file.pages.page(arr[0]).value[:Rotate] || :none
          end
        end

        if @interleave
          max_pages_per_file = 0
          all = @files.each_with_index.map do |spec, findex|
            list = []
            spec.pages.each {|index, rotation| list << [spec.file, findex, index, rotation]}
            max_pages_per_file = list.size if list.size > max_pages_per_file
            list
          end
          first, *rest = *all
          first[max_pages_per_file - 1] ||= nil
          first.zip(*rest) do |slice|
            slice.each do |source, findex, index, rotation|
              next unless source
              import_page(page_tree, source, findex, index, rotation)
            end
          end
        else
          @files.each_with_index do |s, findex|
            s.pages.each {|index, rotation| import_page(page_tree, s.file, findex, index, rotation)}
          end
        end
      end

      # Import the page with index +page_index+ and given +rotation+ from +source+ into the page
      # tree.
      def import_page(page_tree, source, source_index, page_index, rotation)
        page = source.pages.page(page_index)
        if page_tree.document == source
          page.value.update(page.copy_inherited_values)
          page = page.deep_copy unless source_index == 0
        else
          page = page_tree.document.import(page).deep_copy
        end
        if rotation == :none
          page.delete(:Rotate)
        elsif rotation.kind_of?(Integer)
          page[:Rotate] = ((page[:Rotate] || 0) + rotation) % 360
        end
        page_tree.document.add(page)
        page_tree.add_page(page)
      end

      IGNORED_FILTERS = { #:nodoc:
        CCITTFaxDecode: true, JBIG2Decode: true, DCTDecode: true, JPXDecode: true, Crypt: true
      }

      # Applies the chosen stream mode to all streams.
      def handle_streams(doc)
        doc.each(current: false) do |obj|
          next if !obj.respond_to?(:set_filter) || obj[:Subtype] == :Image ||
            Array(obj[:Filter]).any? {|f| IGNORED_FILTERS[f]}
          if @streams == :compress
            obj.set_filter(:FlateDecode)
          else
            obj.set_filter(nil)
          end
        end
      end

    end

  end
end
