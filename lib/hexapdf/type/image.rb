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

require 'hexapdf/stream'

module HexaPDF
  module Type

    # Represents an image XObject of a PDF document.
    #
    # See: PDF1.7 s8.8
    class Image < Stream

      define_field :Type,             type: Symbol,          default: :XObject
      define_field :Subtype,          type: Symbol,          required: true, default: :Image
      define_field :Width,            type: Integer,         required: true
      define_field :Height,           type: Integer,         required: true
      define_field :ColorSpace,       type: [Symbol, Array]
      define_field :BitsPerComponent, type: Integer
      define_field :Intent,           type: Symbol,          version: '1.1'
      define_field :ImageMask,        type: Boolean,         default: false
      define_field :Mask,             type: [Stream, Array], version: '1.3'
      define_field :Decode,           type: Array
      define_field :Interpolate,      type: Boolean,         default: false
      define_field :Alternates,       type: Array,           version: '1.3'
      define_field :SMask,            type: Stream,          version: '1.4'
      define_field :SMaskInData,      type: Integer,         version: '1.5'
      define_field :StructParent,     type: Integer,         version: '1.3'
      define_field :ID,               type: PDFByteString,   version: '1.3'
      define_field :OPI,              type: Dictionary,      version: '1.2'
      define_field :Metadata,         type: Stream,          version: '1.4'
      define_field :OC,               type: Dictionary,      version: '1.5'

      # Returns the source path that was used when creating the image object.
      #
      # This value is only set when the image object was created by using the image loading
      # facility and not when the image is part of a loaded PDF file.
      attr_accessor :source_path

    end

  end
end
