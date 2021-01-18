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

require 'hexapdf/error'
require 'weakref'

module HexaPDF

  # The Importer class manages the process of copying objects from one Document to another.
  #
  # It may seem unnecessary using an importer containing state for the task. However, by retaining
  # some information about the already copied objects we can make sure that already imported
  # objects don't get imported again.
  #
  # Two types of indirect objects are *never* imported from one document to another: the catalog
  # and page tree nodes. If the catalog was imported, the whole source document would be imported.
  # And if one page tree node would imported, the whole page tree would be imported.
  #
  # See: Document#import
  class Importer

    class NullableWeakRef < WeakRef #:nodoc:

      def __getobj__ #:nodoc:
        super rescue nil
      end

    end

    # Returns the Importer object for copying objects from the +source+ to the +destination+
    # document.
    def self.for(source:, destination:)
      @map ||= {}
      @map.keep_if {|_, v| v.source.weakref_alive? && v.destination.weakref_alive? }
      source = NullableWeakRef.new(source)
      destination = NullableWeakRef.new(destination)
      @map[[source.hash, destination.hash]] ||= new(source: source, destination: destination)
    end

    private_class_method :new

    attr_reader :source, :destination #:nodoc:

    # Initializes a new importer that can import objects from the +source+ document to the
    # +destination+ document.
    def initialize(source:, destination:)
      @source = source
      @destination = destination
      @mapper = {}
    end

    # Imports the given +object+ from the source to the destination object and returns the
    # imported object.
    #
    # Note: Indirect objects are automatically added to the destination document but direct or
    # simple objects are not.
    #
    # An error is raised if the object doesn't belong to the +source+ document.
    def import(object)
      mapped_object = @mapper[object.data]&.__getobj__ if object.kind_of?(HexaPDF::Object)
      if object.kind_of?(HexaPDF::Object) && object.document? && @source != object.document
        raise HexaPDF::Error, "Import error: Incorrect document object for importer"
      elsif mapped_object && mapped_object == @destination.object(mapped_object)
        mapped_object
      else
        duplicate(object)
      end
    end

    private

    # Recursively duplicates the object.
    #
    # PDF objects are automatically added to the destination document if they are indirect objects
    # in the source document.
    def duplicate(object)
      case object
      when Hash
        object.transform_values {|v| duplicate(v) }
      when Array
        object.map {|v| duplicate(v) }
      when HexaPDF::Reference
        import(@source.object(object))
      when HexaPDF::Object
        if object.type == :Catalog || object.type == :Pages
          @mapper[object.data] = nil
        else
          obj = object.dup
          @mapper[object.data] = NullableWeakRef.new(obj)
          obj.document = @destination.__getobj__
          obj.instance_variable_set(:@data, obj.data.dup)
          obj.data.oid = 0
          obj.data.gen = 0
          @destination.add(obj) if object.indirect?

          obj.data.stream = obj.data.stream.dup if obj.data.stream.kind_of?(String)
          obj.data.value = duplicate(obj.data.value)
          obj.data.value.update(duplicate(object.copy_inherited_values)) if object.type == :Page
          obj
        end
      when String
        object.dup
      else
        object
      end
    end

  end

end
