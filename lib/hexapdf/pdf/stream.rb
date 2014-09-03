# -*- encoding: utf-8 -*-

require 'stringio'

module HexaPDF
  module PDF

    # Container for read stream data.
    #
    # This helper class wraps all information necessary to read data from an IO stream at a specific
    # offset for a specific length.
    #
    # See: IndirectObject
    Stream = Struct.new(:io, :offset, :length)

  end
end
