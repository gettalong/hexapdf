# -*- encoding: utf-8 -*-

require 'hexapdf/error'
require 'hexapdf/pdf/stream'
require 'hexapdf/pdf/xref_section'

module HexaPDF
  module PDF
    module Type

      # Represents PDF type XRef, cross-reference streams.
      #
      # A cross-reference stream is used as a more compact representation for an cross-reference
      # section and trailer dictionary. The trailer dictionary is incorporated into the stream
      # dictionary and the cross-reference section entries are stored in the stream itself,
      # compressed to save space.
      #
      # == How are Cross-reference Streams Used?
      #
      # Cross-reference stream objects are only used when parsing or writing a PDF document.
      #
      # When a file is read and a cross-reference stream is found, it is loaded and its information
      # is stored in a HexaPDF::PDF::Revision object. So from a user's perspective nothing changes
      # when a cross-reference stream instead of a cross-reference section and trailer is
      # encountered.
      #
      # This also means that all information stored in a cross-reference stream between parsing and
      # writing is discarded when the PDF document gets written!
      #
      # Upon writing a revision it is checked whether that revision contains a cross-reference
      # stream object. If it does the cross-reference stream object is updated with the
      # cross-reference section and trailer information and then written. Otherwise a normal
      # cross-reference section plus trailer are written.
      #
      # See: PDF1.7 s7.5.8
      class XRefStream < HexaPDF::PDF::Stream

        define_field :Type, type: Symbol, default: :XRef, required: true, indirect: false, version: '1.5'
        define_field :Size, type: Integer, required: true, indirect: false
        define_field :Index, type: Array, indirect: false
        define_field :Prev, type: Integer, indirect: false
        define_field :W, type: Array, required: true, indirect: false

        # Returns an XRefSection that represents the content of this cross-reference stream.
        #
        # Each invocation returns a new XRefSection object based on the current data in the associated
        # stream and dictionary.
        def xref_section
          index = self[:Index] || [0, self[:Size]]
          parse_xref_section(index, self[:W])
        end

        # Makes this cross-reference stream represent the data in the given XRefSection and Trailer.
        #
        # The given cross-reference section is *not* stored but only used to rewrite the associated
        # stream to reflect the cross-reference section. The dictionary is updated with the
        # information from the trailer and the needed entries for the cross-reference section.
        #
        # If there are changes to the cross-reference section or trailer, this method has to be
        # invoked again.
        def update_with_xref_section_and_trailer(xref_section, trailer)
          value.replace(trailer)
          value[:Type] = :XRef
          write_xref_section_to_stream(xref_section)
          set_filter(:FlateDecode, {:Columns => value[:W].inject(:+), :Predictor => 12})
        end

        private

        TYPE_FREE       = 0 #:nodoc:
        TYPE_IN_USE     = 1 #:nodoc:
        TYPE_COMPRESSED = 2 #:nodoc:

        # Parses the stream and returns the resulting XRefSection object.
        def parse_xref_section(index, w)
          xref = XRefSection.new

          entry_size = w.inject(:+)
          pos_in_stream = 0

          index.each_slice(2) do |first_oid, number_of_entries|
            number_of_entries.times do |i|
              oid = first_oid + i
              entry = stream[pos_in_stream, entry_size]

              # Default for first field: type 1
              type_field = (w[0] == 0 ? TYPE_IN_USE : bytes_to_int(entry[0, w[0]]))
              # No default available for second field
              field2 = bytes_to_int(entry[w[0], w[1]])
              # Default for third field is 0 for type 1, otherwise it needs to be specified!
              field3 = bytes_to_int(entry[w[0] + w[1], w[2]])

              case type_field
              when TYPE_IN_USE
                xref.add_in_use_entry(oid, field3, field2)
              when TYPE_FREE
                xref.add_free_entry(oid, field3)
              when TYPE_COMPRESSED
                xref.add_compressed_entry(oid, field2, field3)
              else
                # Ignore entry as per PDF1.7 s7.5.8.3
              end
              pos_in_stream += entry_size
            end
          end

          xref
        end

        # Converts the given bytes (a String object) to an integer.
        #
        # The bytes are converted in the big-endian way. If +bytes+ is an empty string, zero is
        # returned.
        def bytes_to_int(bytes)
          bytes.unpack('H*').first.to_i(16)
        end

        # Writes the given cross-reference section to the stream and sets the correct /W and /Index
        # entries for the written data.
        def write_xref_section_to_stream(xref_section)
          value[:W], pack_string = calculate_w_entry_and_pack_string(xref_section[self.oid, self.gen].pos)
          value[:Index] = []

          self.stream = ''
          xref_section.each_subsection do |entries|
            value[:Index] << entries.first.oid << entries.length
            entries.each do |entry|
              data = if entry.in_use?
                       [TYPE_IN_USE, entry.pos, entry.gen]
                     elsif entry.free?
                       [TYPE_FREE, 0, 65535]
                     elsif entry.compressed?
                       [TYPE_COMPRESSED, entry.objstm, entry.pos]
                     else
                       raise HexaPDF::Error, "Unsupported cross-reference entry #{entry}"
                     end
              self.stream << data.pack(pack_string)
            end
          end
        end

        # Returns the /W entry depending on the given maximal number for the second field as well as
        # the appropriate entry packing string.
        def calculate_w_entry_and_pack_string(max_number)
          middle = Math.log(max_number, 255).ceil
          middle = 4 if middle == 3
          pack_string = "C#{middle == 1 ? 'C' : '??SLL'[middle] << '>'}S>"
          [[1, middle, 2], pack_string]
        end

      end

    end
  end
end
