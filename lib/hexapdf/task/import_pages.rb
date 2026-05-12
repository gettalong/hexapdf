# -*- encoding: utf-8; frozen_string_literal: true -*-
#
#--
# This file is part of HexaPDF.
#
# HexaPDF - A Versatile PDF Creation and Manipulation Library For Ruby
# Copyright (C) 2014-2026 Thomas Leitner
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

require 'hexapdf/serializer'
require 'set'

module HexaPDF
  module Task

    # Task for importing pages from another document that preserves the visual appearance.
    #
    # It takes care of
    #
    # * importing the specified pages with all associated objects,
    # * handling optional content groups and their default state,
    # * and merging form fields.
    #
    # Note that the /Order, /AS and /Locked fields of the default optional content configuration
    # dictionary are not preserved.
    #
    # Example:
    #
    #   doc.task(:import_pages, source: source_doc, pages: [1..-2])
    module ImportPages

      # Performs the necessary steps to import the pages from the +source+ docment into the target
      # document +doc+. Returns the imported pages.
      #
      # +source+::
      #     Specifies the source PDF document from which the pages should be imported.
      #
      # +pages+::
      #     Specifies the pages that should be imported. The argument has to be one of the
      #     following:
      #
      #     +:all+:: Imports all pages from the +source+ document.
      #     Integer value:: Imports the page with the given zero-based index.
      #     Range value:: Imports the pages from the zero-based range.
      #     Array of Integer or Range values:: Imports all specified pages or page ranges.
      #     Array of source page objects:: Imports the given pages.
      #
      # +:append+::
      #     Specifies whether the imported pages should be appended to the target document's page
      #     tree.
      #
      # +ocgs+::
      #     Specifies the handling of optional content groups:
      #
      #     +:preserve+:: Preserve the on/off state for all used OCGs.
      #     +:ignore+:: Ignore the on/off state.
      #
      # +:acro_form+::
      #     Specifies whether AcroForm fields should be merged into the target document.
      #
      #     +:merge+:: Merge AcroForm fields using the MergeAcroForm task.
      #     +:ignore+:: Ignore AcroForm fields.
      def self.call(doc, source:, pages: :all, append: true, ocgs: :preserve, acro_form: :merge)
        # Retrieve all specified source pages
        pages = if pages == :all
                  source.pages.each.to_a
                elsif pages.kind_of?(Integer)
                  [source.pages[pages]]
                elsif pages.kind_of?(Array) && pages[0].kind_of?(HexaPDF::Type::Page)
                  pages
                else
                  result = Set.new
                  all_pages = source.pages.each.to_a
                  pages = [pages] unless pages.kind_of?(Array)
                  pages.each {|selector| result.merge(Array(all_pages[selector])) }
                  result
                end

        # Import the source pages and optionally append them to the target page tree
        pages = pages.map do |page|
          imported_page = doc.import(page)
          doc.pages << imported_page if append
          imported_page
        end

        doc.task(:merge_acro_form, source: source, pages: pages) if acro_form == :merge
        preserve_ocgs(doc, source, pages) if ocgs == :preserve

        pages
      end

      # Preserves the state of the OCGs found on +pages+ so that the visual appearance in the target
      # document +doc+ is the same as in the +source+ document.
      def self.preserve_ocgs(doc, source, pages)
        # Find all OCGs used on all pages
        ocgs = Set.new
        process_ocg_or_ocmd = lambda do |obj|
          if obj.type == :OCG
            ocgs << obj
          elsif obj.type == :OCMD
            ocgs.merge(obj[:OCGs].to_ary)
          end
        end
        seen_resources = {}
        pages.each do |page|
          unless seen_resources[page.resources] # handle case when pages share the resources dict
            page.resources[:Properties]&.each do |name, obj|
              next unless obj
              process_ocg_or_ocmd.call(obj)
            end

            page.resources[:XObject]&.each do |name, obj|
              process_ocg_or_ocmd.call(obj[:OC]) if obj.key?(:OC)
            end
          end

          page.each_annotation do |annot|
            process_ocg_or_ocmd.call(annot[:OC]) if annot.key?(:OC)
          end

          seen_resources[page.resources] = true
        end

        return if ocgs.empty?

        # Add all found OCGs to the optional content properties dictionary
        ocp = doc.optional_content
        ocgs.each {|ocg| ocp.add_ocg(ocg) }

        # Create a mapping from source OCGs to target OCGs and vice-versa
        source_ocg = {}
        target_ocg = {}
        source.optional_content.ocgs.each do |ocg|
          imported_ocg = doc.import(ocg)
          next unless ocgs.include?(imported_ocg)
          source_ocg[imported_ocg] = ocg
          target_ocg[ocg] = imported_ocg
        end

        # Ensure the initial state of the OCGs is correct
        source_config = source.optional_content.default_configuration
        target_config = ocp.default_configuration
        ocgs.each do |ocg|
          target_config.ocg_state(ocg, source_config.ocg_state(source_ocg[ocg]))
        end

        # Copy radio button groups from the source document, removing unknown OCGs from them
        source_config[:RBGroups]&.each do |array|
          result = array.map {|ocg| target_ocg[ocg] }.compact
          next if result.empty?
          (target_config[:RBGroups] ||= []) << result
        end
      end

    end

  end
end
