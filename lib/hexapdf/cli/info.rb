# -*- encoding: utf-8 -*-
#
#--
# This file is part of HexaPDF.
#
# HexaPDF - A Versatile PDF Creation and Manipulation Library For Ruby
# Copyright (C) 2014-2017 Thomas Leitner
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

    # Outputs various bits of information about PDF files:
    #
    # * The entries in the trailers /Info dictionary
    # * Encryption information from the trailers /Encrypt dictionary
    # * The number of pages
    # * The used PDF version
    #
    # See: HexaPDF::Type::Info, HexaPDF::Encryption::SecurityHandler
    class Info < Command

      def initialize #:nodoc:
        super('info', takes_commands: false)
        short_desc("Show document information")
        long_desc(<<-EOF.gsub!(/^ */, ''))
          This command extracts information from the Info dictionary of a PDF file as well
          as some other useful information like the used PDF version and encryption information.
        EOF
        options.on("--password PASSWORD", "-p", String,
                   "The password for decryption. Use - for reading from standard input.") do |pwd|
          @password = (pwd == '-' ? read_password : pwd)
        end
        @password = nil
        @auto_decrypt = true
      end

      def execute(file) #:nodoc:
        output_info(file)
      end

      private

      INFO_KEYS = [:Title, :Author, :Subject, :Keywords, :Creator, :Producer, #:nodoc:
                   :CreationDate, :ModDate].freeze

      COLUMN_WIDTH = 20 #:nodoc:

      def output_info(file) # :nodoc:
        options = pdf_options(@password)
        options[:config]['document.auto_decrypt'] = @auto_decrypt
        HexaPDF::Document.open(file, options) do |doc|
          output_line("File name", file)
          output_line("File size", File.stat(file).size.to_s + " bytes")
          @auto_decrypt && INFO_KEYS.each do |name|
            next unless doc.trailer.info.key?(name)
            output_line(name.to_s, doc.trailer.info[name].to_s)
          end

          if doc.encrypted? && @auto_decrypt
            details = doc.security_handler.encryption_details
            data = "yes (version: #{details[:version]}, key length: #{details[:key_length]}bits)"
            output_line("Encrypted", data)
            output_line("  String algorithm", details[:string_algorithm].to_s)
            output_line("  Stream algorithm", details[:stream_algorithm].to_s)
            output_line("  EFF algorithm", details[:embedded_file_algorithm].to_s)
            if doc.security_handler.respond_to?(:permissions)
              output_line("  Permissions", doc.security_handler.permissions.join(", "))
            end
          elsif doc.encrypted?
            output_line("Encrypted", "yes (no or wrong password given)")
          end

          output_line("Pages", doc.pages.count.to_s)
          output_line("Version", doc.version)
        end
      rescue HexaPDF::EncryptionError
        if @auto_decrypt
          @auto_decrypt = false
          retry
        else
          raise
        end
      end

      def output_line(header, text) #:nodoc:
        puts((header + ":").ljust(COLUMN_WIDTH) << text)
      end

    end

  end
end
