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

    # Splits a PDF file, putting each page into a separate file.
    class Split < Command

      def initialize #:nodoc:
        super('split', takes_commands: false)
        short_desc("Split a PDF file into individual pages")
        long_desc(<<~EOF)
          If no OUTPUT_SPEC is specified, the pages are named <PDF>_0001.pdf, <PDF>_0002.pdf, ...
          and so on. To specify a custom name, provide the OUTPUT_SPEC argument. It can contain a
          prinft-style format definition like '%04d' to specify the place where the page number
          should be inserted.

          The optimization and encryption options are applied to each created output file.
        EOF

        options.on("--password PASSWORD", "-p", String,
                   "The password for decryption. Use - for reading from standard input.") do |pwd|
          @password = (pwd == '-' ? read_password : pwd)
        end
        define_optimization_options
        define_encryption_options

        @password = nil
      end

      def execute(pdf, output_spec = pdf.sub(/\.pdf$/i, '_%04d.pdf')) #:nodoc:
        output_spec = output_spec.sub('%', '%<page>')
        with_document(pdf, password: @password) do |doc|
          doc.pages.each_with_index do |page, index|
            output_file = sprintf(output_spec, page: index + 1)
            maybe_raise_on_existing_file(output_file)
            out = HexaPDF::Document.new
            out.pages.add(out.import(page))
            apply_encryption_options(out)
            apply_optimization_options(out)
            write_document(out, output_file)
          end
        end
      end

    end

  end
end
