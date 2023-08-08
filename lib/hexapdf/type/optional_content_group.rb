# -*- encoding: utf-8; frozen_string_literal: true -*-
#
#--
# This file is part of HexaPDF.
#
# HexaPDF - A Versatile PDF Creation and Manipulation Library For Ruby
# Copyright (C) 2014-2023 Thomas Leitner
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

require 'hexapdf/dictionary'

module HexaPDF
  module Type

    # Represents an optional content group.
    #
    # An optional content group represents graphics that can be made visible or invisible
    # dynamically by the PDF processor. These graphics may reside in any content stream and don't
    # need to be consecutive with respect to the drawing order.
    #
    # Most PDF viewers call this feature "layers" since it is often used to show/hide parts of
    # drawings or maps.
    #
    # See: PDF2.0 s8.11.2
    class OptionalContentGroup < Dictionary

      # Represents an optional content group's usage dictionary which describes how the content
      # controlled by the group should be used.
      #
      # See: PDF2.0 s8.11.4.4
      class OptionalContentUsage < Dictionary

        # The dictionary used as value for the /CreatorInfo key.
        #
        # See: PDF2.0 s8.11.4.4
        class CreatorInfo < Dictionary
          define_type :XXOCUsageCreatorInfo
          define_field :Creator, type: String, required: true
          define_field :Subtype, type: Symbol, required: true
        end

        # The dictionary used as value for the /Language key.
        #
        # See: PDF2.0 s8.11.4.4
        class Language < Dictionary
          define_type :XXOCUsageLanguage
          define_field :Lang, type: String, required: true
          define_field :Preferred, type: Symbol, default: :OFF, allowed_values: [:ON, :OFF]
        end

        # The dictionary used as value for the /Export key.
        #
        # See: PDF2.0 s8.11.4.4
        class Export < Dictionary
          define_type :XXOCUsageExport
          define_field :ExportState, type: Symbol, required: true, allowed_values: [:ON, :OFF]
        end

        # The dictionary used as value for the /Zoom key.
        #
        # See: PDF2.0 s8.11.4.4
        class Zoom < Dictionary
          define_type :XXOCUsageZoom
          define_field :min, type: Numeric, default: 0
          define_field :max, type: Numeric
        end

        # The dictionary used as value for the /Print key.
        #
        # See: PDF2.0 s8.11.4.4
        class Print < Dictionary
          define_type :XXOCUsagePrint
          define_field :Subtype, type: Symbol
          define_field :PrintState, type: Symbol, allowed_values: [:ON, :OFF]
        end

        # The dictionary used as value for the /View key.
        #
        # See: PDF2.0 s8.11.4.4
        class View < Dictionary
          define_type :XXOCUsageView
          define_field :ViewState, type: Symbol, required: true, allowed_values: [:ON, :OFF]
        end

        # The dictionary used as value for the /User key.
        #
        # See: PDF2.0 s8.11.4.4
        class User < Dictionary
          define_type :XXOCUsageUser
          define_field :Type, type: Symbol, required: true, allowed_values: [:Ind, :Ttl, :Org]
          define_field :Name, type: [String, PDFArray], required: true
        end

        # The dictionary used as value for the /PageElement key.
        #
        # See: PDF2.0 s8.11.4.4
        class PageElement < Dictionary
          define_type :XXOCUsagePageElement
          define_field :Subtype, type: Symbol, required: true, allowed_values: [:HF, :FG, :BG, :L]
        end

        define_type :XXOCUsage

        define_field :CreatorInfo, type: :XXOCUsageCreatorInfo
        define_field :Language,    type: :XXOCUsageLanguage
        define_field :Export,      type: :XXOCUsageExport
        define_field :Zoom,        type: :XXOCUsageZoom
        define_field :Print,       type: :XXOCUsagePrint
        define_field :View,        type: :XXOCUsageView
        define_field :User,        type: :XXOCUsageUser
        define_field :PageElement, type: :XXOCUsagePageElement

      end

      define_type :OCG

      define_field :Type,   type: Symbol, required: true, default: type
      define_field :Name,   type: String, required: true
      define_field :Intent, type: [Symbol, PDFArray], default: :View
      define_field :Usage,  type: :XXOCUsage

    end

  end
end
