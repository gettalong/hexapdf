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

require 'io/console'
require 'ostruct'
require 'cmdparse'
require 'hexapdf/document'

module HexaPDF
  module CLI

    # Base class for all hexapdf commands. It provides utility methods needed by the individual
    # commands.
    class Command < CmdParse::Command

      def initialize(*args, &block) #:nodoc:
        super
        @out_options = OpenStruct.new
        @out_options.compact = true
        @out_options.compress_pages = false
        @out_options.object_streams = :preserve
        @out_options.xref_streams = :preserve
        @out_options.streams = :preserve

        @out_options.encryption = :preserve
        @out_options.enc_user_pwd = @out_options.enc_owner_pwd = nil
        @out_options.enc_key_length = 128
        @out_options.enc_algorithm = :aes
        @out_options.enc_force_v4 = false
        @out_options.enc_permissions = []
      end

      protected

      # Checks whether the given output file exists and raises an error if it does.
      #
      # Uses HexaPDF::CLI#force to determine if the error should be raised or ignored.
      def check_output_file(filename)
        if !command_parser.force && File.exist?(filename)
          raise "Not overwriting existing output file '#{filename}' due to --no-force"
        end
      end

      # Defines the optimization options.
      #
      # See: #out_options, #apply_optimization_options
      def define_optimization_options
        options.on("--[no-]compact", "Delete unnecessary PDF objects (default: " \
                   "#{@out_options.compact})") do |c|
          @out_options.compact = c
        end
        options.on("--object-streams MODE", [:generate, :preserve, :delete],
                   "Handling of object streams (either generate, preserve or delete; " \
                     "default: #{@out_options.object_streams})") do |os|
          @out_options.object_streams = os
        end
        options.on("--xref-streams MODE", [:generate, :preserve, :delete],
                   "Handling of cross-reference streams (either generate, preserve or delete; " \
                     "default: #{@out_options.xref_streams})") do |x|
          @out_options.xref_streams = x
        end
        options.on("--streams MODE", [:compress, :preserve, :uncompress],
                   "Handling of stream data (either compress, preserve or uncompress; default: " \
                     "#{@out_options.streams})") do |streams|
          @out_options.streams = streams
        end
        options.on("--[no-]compress-pages", "Recompress page content streams (may take a long " \
                   "time; default: #{@out_options.compress_pages})") do |c|
          @out_options.compress_pages = c
        end
      end

      # Defines the encryption options.
      #
      # See: #out_options, #apply_encryption_options
      def define_encryption_options
        options.on("--decrypt", "Remove any encryption") do
          @out_options.encryption = :remove
        end
        options.on("--encrypt", "Encrypt the output file") do
          @out_options.encryption = :add
        end
        options.on("--owner-password PASSWORD", String, "The owner password to be set on the " \
                   "output file (use - for reading from standard input)") do |pwd|
          @out_options.encryption = :add
          @out_options.enc_owner_pwd = (pwd == '-' ? read_password("Owner password") : pwd)
        end
        options.on("--user-password PASSWORD", String, "The user password to be set on the " \
                   "output file (use - for reading from standard input)") do |pwd|
          @out_options.encryption = :add
          @out_options.enc_user_pwd = (pwd == '-' ? read_password("User password") : pwd)
        end
        options.on("--algorithm ALGORITHM", [:aes, :arc4],
                   "The encryption algorithm: aes or arc4 (default: " \
                     "#{@out_options.enc_algorithm})") do |a|
          @out_options.encryption = :add
          @out_options.enc_algorithm = a
        end
        options.on("--key-length BITS", Integer,
                   "The encryption key length in bits (default: " \
                     "#{@out_options.enc_key_length})") do |i|
          @out_options.encryption = :add
          @out_options.enc_key_length = i
        end
        options.on("--force-V4",
                   "Force use of encryption version 4 if key length=128 and algorithm=arc4") do
          @out_options.encryption = :add
          @out_options.enc_force_v4 = true
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
          @out_options.encryption = :add
          @out_options.enc_permissions = perms
        end
      end

      # Applies the optimization options to the given HexaPDF::Document instance.
      #
      # See: #define_optimization_options
      def apply_optimization_options(doc)
        doc.task(:optimize, compact: @out_options.compact,
                 object_streams: @out_options.object_streams,
                 xref_streams: @out_options.xref_streams,
                 compress_pages: @out_options.compress_pages)
        handle_streams(doc) unless @out_options.streams == :preserve
      end

      IGNORED_FILTERS = { #:nodoc:
        CCITTFaxDecode: true, JBIG2Decode: true, DCTDecode: true, JPXDecode: true, Crypt: true
      }.freeze

      # Applies the chosen stream mode to all streams.
      def handle_streams(doc)
        doc.each(current: false) do |obj|
          next if !obj.respond_to?(:set_filter) || Array(obj[:Filter]).any? {|f| IGNORED_FILTERS[f]}
          if @out_options.streams == :compress
            obj.set_filter(:FlateDecode)
          else
            obj.set_filter(nil)
          end
        end
      end

      # Applies the encryption related options to the given HexaPDF::Document instance.
      #
      # See: #define_encryption_options
      def apply_encryption_options(doc)
        if @out_options.encryption == :add
          doc.encrypt(algorithm: @out_options.enc_algorithm,
                      key_length: @out_options.enc_key_length,
                      force_V4: @out_options.enc_force_v4,
                      permissions: @out_options.enc_permissions,
                      owner_password: @out_options.enc_owner_pwd,
                      user_password: @out_options.enc_user_pwd)
        elsif @out_options.encryption == :remove
          doc.encrypt(name: nil)
        end
      end

      PAGE_NUMBER_SPEC = "([1-9]\\d*|e)".freeze #:nodoc:
      ROTATE_MAP = {'l' => -90, 'r' => 90, 'd' => 180, 'n' => :none}.freeze #:nodoc:

      # Parses the pages specification string and returns an array of tuples containing a page
      # number and a rotation value (either -90, 90, 180 or :none).
      #
      # The parameter +count+ needs to be the total number of pages in the document.
      #
      # For details on the pages specification see the hexapdf(1) manual page.
      def parse_pages_specification(range, count)
        range.split(',').each_with_object([]) do |str, arr|
          case str
          when /\A#{PAGE_NUMBER_SPEC}(l|r|d|n)?\z/o
            arr << [($1 == 'e' ? count : str.to_i) - 1, ROTATE_MAP[$2]]
          when /\A#{PAGE_NUMBER_SPEC}-#{PAGE_NUMBER_SPEC}(?:\/([1-9]\d*))?(l|r|d|n)?\z/
            start_nr = ($1 == 'e' ? count : $1.to_i) - 1
            end_nr = ($2 == 'e' ? count : $2.to_i) - 1
            step = ($3 ? $3.to_i : 1) * (start_nr > end_nr ? -1 : 1)
            rotation = ROTATE_MAP[$4]
            start_nr.step(to: end_nr, by: step) {|n| arr << [n, rotation]}
          else
            raise OptionParser::InvalidArgument, "invalid page range format: #{str}"
          end
        end
      end

      # Reads a password from the standard input and falls back to the console if needed.
      #
      # The optional argument +prompt+ can be used to customize the prompt when reading from the
      # console.
      def read_password(prompt = "Password")
        if $stdin.tty?
          read_from_console(prompt)
        else
          pwd = $stdin.gets
          pwd = read_from_console(prompt) unless pwd
          pwd.chomp
        end
      end

      private

      # Displays the given prompt, reads from the console without echo and returns the read string.
      def read_from_console(prompt)
        IO.console.write("#{prompt}: ")
        str = IO.console.noecho {|io| io.gets.chomp}
        puts
        str
      end

    end

  end
end
