# -*- encoding: utf-8; frozen_string_literal: true -*-
#
#--
# This file is part of HexaPDF.
#
# HexaPDF - A Versatile PDF Creation and Manipulation Library For Ruby
# Copyright (C) 2014-2025 Thomas Leitner
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
require 'hexapdf/serializer'
require 'hexapdf/content/parser'
require 'hexapdf/content/operator'
require 'hexapdf/type/xref_stream'
require 'hexapdf/type/object_stream'

module HexaPDF
  module Task

    # Task for creating a PDF/A compliant document.
    #
    # It automatically
    #
    # * prevents the Standard 14 PDF fonts to be used.
    # * adds an appropriate output intent if none is set.
    # * adds the necessary PDF/A metadata properties.
    module PDFA

      # Performs the necessary tasks to make the document PDF/A compatible.
      #
      # +level+::
      #     Specifies the PDF/A conformance level that should be used. Can be one of the following
      #     strings: 2b, 2u, 3b, 3u.
      def self.call(doc, level: '3u')
        unless level.match?(/\A[23][bu]\z/)
          raise ArgumentError, "The given PDF/A conformance level '#{level}' is not supported"
        end
        doc.config['font_loader'].delete('HexaPDF::FontLoader::Standard14')
        doc.register_listener(:complete_objects) do
          part, conformance = level.chars
          doc.metadata.property('pdfaid', 'part', part)
          doc.metadata.property('pdfaid', 'conformance', conformance.upcase)
          add_srgb_icc_output_intent(doc) unless doc.catalog.key?(:OutputIntents)
        end
      end

      SRGB_ICC = 'sRGB2014.icc' # :nodoc:

      def self.add_srgb_icc_output_intent(doc) # :nodoc:
        icc = doc.add({N: 3}, stream: File.binread(File.join(HexaPDF.data_dir, SRGB_ICC)))
        doc.catalog[:OutputIntents] = [
          doc.add({S: :GTS_PDFA1, OutputConditionIdentifier: SRGB_ICC, Info: SRGB_ICC,
                   RegistryName: 'https://www.color.org', DestOutputProfile: icc}),
        ]
      end

    end

  end
end
