# -*- encoding: utf-8 -*-

require 'set'
require 'stringio'
require 'hexapdf/error'
require 'hexapdf/pdf/stream'
require 'hexapdf/pdf/reference'
require 'hexapdf/pdf/tokenizer'
require 'hexapdf/pdf/serializer'

module HexaPDF
  module PDF
    module Type

      # Represents PDF type ObjStm, object streams.
      #
      # When a stream is assigned to an ObjectStream (either on creation or via #stream=), the
      # internal state in respect to the ObjectStream data is reset and then the offsets are read
      # and cached for later use. After that only the objects themselves are read from the stream.
      #
      # This means that all information about added objects is lost after assigning a stream!
      #
      # Objects that should be contained in this object stream when it is written, can be managed
      # with the various object methods.
      #
      # See PDF1.7 s7.5.7
      class ObjectStream < HexaPDF::PDF::Stream

        # Holds all necessary information to load objects for an object stream.
        class Data

          # Initializes the data object with the needed values.
          def initialize(stream_data, oids, offsets)
            @tokenizer = Tokenizer.new(StringIO.new(stream_data))
            @offsets = offsets
            @oids = oids
          end

          # Returns the object specified by the given index together with its object number.
          #
          # Objects are not pre-loaded, so every time this method is invoked the associated stream
          # data is parsed and a new object returned.
          def object_by_index(index)
            if index >= @offsets.size || index < 0
              raise HexaPDF::Error, "Invalid index into object stream given"
            end

            @tokenizer.pos = @offsets[index]
            [@tokenizer.parse_object, @oids[index]]
          end

        end


        define_field :Type, type: Symbol, required: true, default: :ObjStm, version: '1.5'
        define_field :N, type: Integer, required: true
        define_field :First, type: Integer, required: true
        define_field :Extends, type: HexaPDF::PDF::Stream


        # Parses the stream and returns a Data object that can be used for retrieving the objects
        # defined by this object stream.
        #
        # The object references are also added to this object stream so that they are included when
        # the object gets written.
        def parse_stream
          oids, offsets = parse_oids_and_offsets
          oids.each {|oid| add_object(Reference.new(oid, 0))}
          Data.new(stream.dup, oids, offsets)
        end

        # Adds the given object to the list of objects that should be stored in this object stream.
        #
        # The parameter +ref+ can either be a reference or any PDF object.
        def add_object(ref)
          return if object_index(ref)

          index = objects.size / 2
          objects[index] = ref
          objects[ref] = index
        end

        # Deletes the given object from the list of objects that should be stored in this object stream.
        def delete_object(ref)
          index = objects[ref]
          return unless index

          move_index = objects.size / 2 - 1

          objects[index] = objects[move_index]
          objects[objects[index]] = index
          objects.delete(ref)
          objects.delete(move_index)
        end

        # Returns the index into the array containing the to-be-stored objects for the given object.
        def object_index(obj)
          objects[obj]
        end

        # Writes the added objects to the stream.
        #
        # There are some reasons why an added object may not be stored in the stream:
        #
        # * It has a generation number other than 0.
        # * It is a stream object.
        # * It doesn't reside in the given Revision object.
        #
        # Such objects are also deleted from the list of to-be-stored objects.
        def write_objects(revision)
          index = 0
          object_info = ''.force_encoding(Encoding::BINARY)
          data = ''.force_encoding(Encoding::BINARY)
          serializer = Serializer.new

          while index < objects.size / 2
            obj = revision.object(objects[index])
            if obj.nil? || obj.null? || obj.gen != 0 || obj.kind_of?(Stream)
              delete_object(objects[index])
              next
            end

            object_info << "#{obj.oid} #{data.size} "
            data << serializer.serialize(obj) << " "
            index += 1
          end

          value[:Type] = :ObjStm
          value[:N] = objects.size / 2
          value[:First] = object_info.size
          self.stream = object_info << data
          set_filter(:FlateDecode)
        end

        private

        # Parses the object numbers and their offsets from the start of the stream data.
        def parse_oids_and_offsets
          oids = []
          offsets = []
          first = value[:First].to_i

          stream_tokenizer = Tokenizer.new(StringIO.new(stream))
          stream.size > 0 && value[:N].to_i.times do
            oids << stream_tokenizer.parse_object
            offsets << first + stream_tokenizer.parse_object
          end

          [oids, offsets]
        end

        # Returns the container with the to-be-stored objects.
        def objects
          @objects ||= {}
        end

      end

    end
  end
end
