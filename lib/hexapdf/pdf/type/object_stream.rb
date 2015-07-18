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
      # An object stream is a stream that can hold multiple indirect objects. Since the objects are
      # stored inside the stream, filters can be used to compress the stream content and therefore
      # represent the indirect objects more compactly than would be possible otherwise.
      #
      # == How are Object Streams Used?
      #
      # When an indirect object that resides in an object stream needs to be loaded, the object
      # stream itself is parsed and loaded and #parse_stream is invoked to get a Data object
      # representing the stored indirect objects. After that the requested indirect object itself is
      # loaded and returned using this Data object. From a user's perspective nothing changes when
      # an object is located inside an object stream instead of directly in a PDF file.
      #
      # The indirect objects initially stored in the object stream are automatically added to the
      # list of to-be-stored objects when #parse_stream is invoked. Additional objects can be
      # assigned to the object stream via #add_object or deleted from it via #delete_object.
      #
      # Before an object stream is written, it is necessary to invoke #write_objects so that the
      # to-be-stored objects are serialized to the stream. This is automatically done by the Writer.
      # A user thus only has to define which objects should reside in the object stream.
      #
      # However, only objects that can be written to the object stream are actually written. The
      # other objects are deleted from the object stream (#delete_object) and written normally.
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
            [@tokenizer.next_object, @oids[index]]
          end

        end


        define_field :Type,    type: Symbol, required: true, default: :ObjStm, version: '1.5'
        define_field :N,       type: Integer # not required, will be auto-filled on #write_objects
        define_field :First,   type: Integer # not required, will be auto-filled on #write_objects
        define_field :Extends, type: Stream

        define_validator(:validate_gen_number)

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
        # The +ref+ argument can either be a reference or any PDF object.
        def add_object(ref)
          return if object_index(ref)

          index = objects.size / 2
          objects[index] = ref
          objects[ref] = index
        end

        # Deletes the given object from the list of objects that should be stored in this object
        # stream.
        #
        # The +ref+ argument can either be a reference or a PDF object.
        def delete_object(ref)
          index = objects[ref]
          return unless index

          move_index = objects.size / 2 - 1

          objects[index] = objects[move_index]
          objects[objects[index]] = index
          objects.delete(ref)
          objects.delete(move_index)
        end

        # Returns the index into the array containing the to-be-stored objects for the given
        # reference/PDF object.
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
        # Such objects are additionally deleted from the list of to-be-stored objects and are later
        # written as indirect objects.
        def write_objects(revision)
          index = 0
          object_info = ''.force_encoding(Encoding::BINARY)
          data = ''.force_encoding(Encoding::BINARY)
          serializer = Serializer.new

          encrypt_dict = document.trailer[:Encrypt]
          while index < objects.size / 2
            obj = revision.object(objects[index])
            if obj.nil? || obj.null? || obj.gen != 0 || obj.kind_of?(Stream) || obj == encrypt_dict
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
            oids << stream_tokenizer.next_object
            offsets << first + stream_tokenizer.next_object
          end

          [oids, offsets]
        end

        # Returns the container with the to-be-stored objects.
        def objects
          @objects ||= {}
        end

        # Validates that the generation number of the object stream is zero.
        def validate_gen_number
          yield("Object stream has invalid generation number > 0", false) if gen != 0
        end

      end

    end
  end
end
