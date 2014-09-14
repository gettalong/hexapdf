# -*- encoding: utf-8 -*-

module HexaPDF
  module PDF

    # == Overview
    #
    # A *stream filter* is used to compress a stream or to encode it in an ASCII compatible way; or
    # to reverse this process. Some filters can be used for any content, like FlateDecode, others
    # are specifically designed for image streams, like DCTDecode.
    #
    # Each filter is implemented via fibers. This allows HexaPDF to easily process either small
    # chunks or a whole stream at once, depending on the memory restrictions.
    #
    # It also allows the easy re-processing of a stream without first decoding and the encoding it.
    # Such functionality is useful, for example, when a PDF file should be decrypted and streams
    # compressed in one step.
    #
    #
    # == Implementation of a Filter Module
    #
    # Each filter is an object (normally a module) that responds to two methods: #encoder and
    # #decoder. Both of these methods are given a *source* (a Fiber) and *options* (a Hash) and have
    # to return a Fiber object.
    #
    # The returned fiber should resume the *source* fiber to get the next chunk of data (possibly
    # only one byte of data, so this situation should be handled gracefully). Once the fiber has
    # processed this chunk, it should yield the processed chunk as binary string. This should be
    # done as long as the source fiber is #alive? and doesn't return +nil+ when resumed.
    #
    # See: PDF1.7 s7.4
    module Filter

      autoload(:ASCII85Decode, 'hexapdf/pdf/filter/ascii85_decode')
      autoload(:ASCIIHexDecode, 'hexapdf/pdf/filter/ascii_hex_decode')
      autoload(:DCTDecode, 'hexapdf/pdf/filter/dct_decode')
      autoload(:FlateDecode, 'hexapdf/pdf/filter/flate_decode')
      autoload(:JPXDecode, 'hexapdf/pdf/filter/jpx_decode')
      autoload(:LZWDecode, 'hexapdf/pdf/filter/lzw_decode')
      autoload(:RunLengthDecode, 'hexapdf/pdf/filter/run_length_decode')

      autoload(:Predictor, 'hexapdf/pdf/filter/predictor')

    end

  end
end
