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
    # * Decrypts or encrypts the PDF file.
    # * Generates or deletes object and cross-reference streams.
    # * Optimizes a PDF by merging the revisions of a PDF file and removes unused entries.
    #
    # See: HexaPDF::Task::Optimize
    class Modify < CmdParse::Command

      def initialize #:nodoc:
        super('modify', takes_commands: false)
        short_desc("Modify a PDF file")
        long_desc(<<-EOF.gsub!(/^ */, ''))
          This command modifies a PDF file. It can be used to encrypt/decrypt a file, to optimize it
          and remove unused entries and to generate or delete object and cross-reference streams.
        EOF

        options.on("--password PASSWORD", "-p", String,
                   "The password for decryption. Use - for reading from standard input.") do |pwd|
          @password = (pwd == '-' ? command_parser.read_password("Input file password") : pwd)
        end
        options.on("--pages PAGES", "The pages to be used in the output file") do |pages|
          @pages = pages
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

        options.separator("")
        options.separator("Encryption related options")
        options.on("--decrypt", "Remove any encryption") do
          @encryption = :remove
        end
        options.on("--encrypt", "Encrypt the output file") do
          @encryption = :add
        end
        options.on("--owner-password PASSWORD", String, "The owner password to be set on the " \
                   "output file. Use - for reading from standard input.") do |pwd|
          @encryption = :add
          @enc_owner_pwd = (pwd == '-' ? command_parser.read_password("Owner password") : pwd)
        end
        options.on("--user-password PASSWORD", String, "The user password to be set on the " \
                   "output file. Use - for reading from standard input.") do |pwd|
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
          perms.each do |perm|
            unless syms.include?(perm)
              raise OptionParser::InvalidArgument, "#{perm} (invalid permission name)"
            end
          end
          @encryption = :add
          @enc_permissions = perms
        end

        @password = nil
        @pages = '1-e'
        @compact = true
        @object_streams = :preserve
        @xref_streams = :preserve

        @encryption = :preserve
        @enc_user_pwd = @enc_owner_pwd = nil
        @enc_key_length = 128
        @enc_algorithm = :aes
        @enc_force_v4 = false
        @enc_permissions = []
      end

      def execute(input_file, output_file) #:nodoc:
        @compact = true unless @pages == '1-e'
        if @enc_user_pwd && !@enc_user_pwd.empty? && (!@enc_owner_pwd || @enc_owner_pwd.empty?)
          @enc_owner_pwd = @enc_user_pwd
        end

        HexaPDF::Document.open(input_file, decryption_opts: {password: @password}) do |doc|
          arrange_pages(doc) unless @pages == '1-e'

          doc.task(:optimize, compact: @compact, object_streams: @object_streams,
                   xref_streams: @xref_streams)

          if @encryption == :add
            doc.encrypt(algorithm: @enc_algorithm, key_length: @enc_key_length,
                        force_V4: @enc_force_v4, permissions: @enc_permissions,
                        owner_password: @enc_owner_pwd, user_password: @enc_user_pwd)
          elsif @encryption == :remove
            doc.encrypt(name: nil)
          end

          doc.write(output_file)
        end
      rescue HexaPDF::Error => e
        $stderr.puts "Error while processing the PDF file: #{e.message}"
        exit(1)
      end

      private

      # Arranges the pages of the document as specified with the --pages option.
      def arrange_pages(doc)
        pages = command_parser.parse_pages_specification(@pages, doc.pages.page_count).map do |i|
          doc.pages.page(i)
        end
        new_page_tree = doc.catalog[:Pages] = doc.add(Type: :Pages)
        pages.each do |page|
          page.value.update(page.copy_inherited_values)
          new_page_tree.add_page(page)
        end
      end

    end

  end
end
