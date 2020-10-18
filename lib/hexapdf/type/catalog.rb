# -*- encoding: utf-8; frozen_string_literal: true -*-
#
#--
# This file is part of HexaPDF.
#
# HexaPDF - A Versatile PDF Creation and Manipulation Library For Ruby
# Copyright (C) 2014-2020 Thomas Leitner
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
require 'hexapdf/number_tree_node'
require 'hexapdf/stream'

module HexaPDF
  module Type

    # Represents the PDF's catalog dictionary which is at the root of the document's object
    # hierarchy.
    #
    # The catalog dictionary is linked via the /Root entry from the Trailer.
    #
    # See: PDF1.7 s7.7.2, Trailer
    class Catalog < Dictionary

      define_type :Catalog

      define_field :Type,              type: Symbol,     required: true, default: type
      define_field :Version,           type: Symbol,     version: '1.4'
      define_field :Extensions,        type: Dictionary, version: '1.7'
      # Pages field is required but this is handled in #perform_validation
      define_field :Pages,             type: :Pages, indirect: true
      define_field :PageLabels,        type: NumberTreeNode, version: '1.3'
      define_field :Names,             type: :XXNames, version: '1.2'
      define_field :Dests,             type: Dictionary, version: '1.1'
      define_field :ViewerPreferences, type: :XXViewerPreferences, version: '1.2'
      define_field :PageLayout,        type: Symbol,     default: :SinglePage,
        allowed_values: [:SinglePage, :OneColumn, :TwoColumnLeft, :TwoColumnRight,
                         :TwoPageLeft, :TwoPageRight]
      define_field :PageMode,          type: Symbol,     default: :UseNone,
        allowed_values: [:UseNone, :UseOutlines, :UseThumbs, :FullScreen, :UseOC, :UseAttachments]
      define_field :Outlines,          type: Dictionary, indirect: true
      define_field :Threads,           type: PDFArray,   version: '1.1'
      define_field :OpenAction,        type: [Dictionary, PDFArray], version: '1.1'
      define_field :AA,                type: Dictionary, version: '1.4'
      define_field :URI,               type: Dictionary, version: '1.1'
      define_field :AcroForm,          type: :XXAcroForm, version: '1.2'
      define_field :Metadata,          type: Stream,     indirect: true, version: '1.4'
      define_field :StructTreeRoot,    type: Dictionary, version: '1.3'
      define_field :MarkInfo,          type: Dictionary, version: '1.4'
      define_field :Lang,              type: String,     version: '1.4'
      define_field :SpiderInfo,        type: Dictionary, version: '1.3'
      define_field :OutputIntents,     type: PDFArray,   version: '1.4'
      define_field :PieceInfo,         type: Dictionary, version: '1.4'
      define_field :OCProperties,      type: Dictionary, version: '1.5'
      define_field :Perms,             type: Dictionary, version: '1.5'
      define_field :Legal,             type: Dictionary, version: '1.5'
      define_field :Requirements,      type: PDFArray,   version: '1.7'
      define_field :Collection,        type: Dictionary, version: '1.7'
      define_field :NeedsRendering,    type: Boolean,    version: '1.7'

      # Returns +true+ since catalog objects must always be indirect.
      def must_be_indirect?
        true
      end

      # Returns the root node of the page tree.
      #
      # See: PageTreeNode
      def pages
        self[:Pages] ||= document.add({Type: :Pages})
      end

      # Returns the main AcroForm object.
      #
      # * If an AcroForm object exists, the +create+ argument is not used.
      #
      # * If no AcroForm object exists and +create+ is +true+, a new AcroForm object with default
      #   settings will be created and returned.
      #
      # * If no AcroForm object exists and +create+ is +false+, +nil+ is returned.
      #
      # See: AcroForm::Form
      def acro_form(create: false)
        if (form = self[:AcroForm])
          form
        elsif create
          form = self[:AcroForm] = document.add({}, type: :XXAcroForm)
          form.set_default_appearance_string
          form
        end
      end

      private

      # Ensures that there is a valid page tree.
      def perform_validation(&block)
        super
        unless key?(:Pages)
          yield("A PDF document needs a page tree", true)
          value[:Pages] = document.add({Type: :Pages})
          value[:Pages].validate(&block)
        end
      end

    end

  end
end
