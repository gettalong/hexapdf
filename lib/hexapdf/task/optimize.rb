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

require 'set'
require 'hexapdf/serializer'
require 'hexapdf/content/parser'
require 'hexapdf/content/operator'

module HexaPDF
  module Task

    # Task for optimizing the PDF document.
    #
    # For a list of optimization methods this task can perform have a look at the ::call method.
    module Optimize

      # Optimizes the PDF document.
      #
      # The field entries that are optional and set to their default value are always deleted.
      # Additional optimization methods are performed depending on the values of the following
      # arguments:
      #
      # compact::
      #   Compacts the object space by merging the revisions and then deleting null and unused
      #   values if set to +true+.
      #
      # object_streams::
      #   Specifies if and how object streams should be used: For :preserve, existing object
      #   streams are preserved; for :generate objects are packed into object streams as much as
      #   possible; and for :delete existing object streams are deleted.
      #
      # compress_pages::
      #   Compresses the content streams of all pages if set to +true+. Note that this can take a
      #   *very* long time because each content stream has to be unfiltered, parsed, serialized
      #   and then filtered again.
      def self.call(doc, compact: false, object_streams: :preserve, compress_pages: false)
        if compact
          compact(doc, object_streams, &method(:delete_fields_with_defaults))
        elsif object_streams != :preserve
          process_object_streams(doc, object_streams, &method(:delete_fields_with_defaults))
        else
          doc.each(current: false, &method(:delete_fields_with_defaults))
        end

        compress_pages(doc) if compress_pages
      end

      # Compacts the document by merging all revisions into one, deleting null and unused entries
      # and renumbering the objects if needed.
      #
      # For the meaning of the other arguments see ::call.
      def self.compact(doc, object_streams)
        doc.revisions.merge
        unused = Set.new(doc.task(:dereference))
        rev = doc.revisions.add

        oid = 1
        xref_stream = false
        doc.revisions[0].each do |obj|
          next if obj.null? || unused.include?(obj) || (xref_stream && obj.type == :XRef) ||
            (obj.type == :ObjStm && object_streams != :preserve)

          xref_stream = true if obj.type == :XRef
          yield(obj) if block_given?
          obj.oid = oid
          obj.gen = 0
          rev.add(obj)
          oid += 1
        end
        doc.revisions.delete(0)

        process_object_streams(doc, :generate) if object_streams == :generate
      end

      # Processes the object streams in each revision according to method: For :preserve, nothing
      # is done, for :disable all object streams are deleted and for :generate objects are packed
      # into object streams as much as possible.
      def self.process_object_streams(doc, method)
        case method
        when :preserve
          # nothing to do
        when :delete
          doc.each(current: false) do |obj, rev|
            if obj.type == :ObjStm
              rev.delete(obj)
            else
              yield(obj) if block_given?
            end
          end
        when :generate
          doc.revisions.each_with_index do |rev, rev_index|
            xref_stream = false
            count = 0
            objstms = [doc.wrap(Type: :ObjStm)]
            rev.each do |obj|
              if obj.type == :XRef
                xref_stream = true
              elsif obj.type == :ObjStm
                rev.delete(obj)
              end
              yield(obj) if block_given?

              next if obj.respond_to?(:stream)

              objstms[-1].add_object(obj)
              count += 1
              if count == 200
                objstms << doc.wrap(Type: :ObjStm)
                count = 0
              end
            end
            objstms.each {|objstm| doc.add(objstm, revision: rev_index)}
            doc.add({Type: :XRef}, revision: rev_index) unless xref_stream
          end
        end
      end

      # Deletes field entries of the object that are optional and currently set to their default
      # value.
      def self.delete_fields_with_defaults(obj)
        return unless obj.kind_of?(HexaPDF::Dictionary) && !obj.null?
        obj.each do |name, value|
          if (field = obj.class.field(name)) && !field.required? && field.default? &&
              value == field.default
            obj.delete(name)
          end
        end
      end

      # Compresses the contents of all pages by parsing and then serializing again. The HexaPDF
      # serializer is already optimized for small output size so nothing else needs to be done.
      def self.compress_pages(doc)
        doc.pages.each_page do |page|
          processor = SerializationProcessor.new
          HexaPDF::Content::Parser.parse(page.contents, processor)
          page.contents = processor.result
          page[:Contents].set_filter(:FlateDecode)
        end
      end

      # This processor is used when compressing pages.
      class SerializationProcessor #:nodoc:

        attr_reader :result #:nodoc:

        def initialize #:nodoc:
          @result = ''.b
          @serializer = HexaPDF::Serializer.new
        end

        def process(op, operands) #:nodoc:
          @result << HexaPDF::Content::Operator::DEFAULT_OPERATORS[op.intern].serialize(@serializer, *operands)
        end

      end

    end

  end
end
