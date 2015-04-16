# -*- encoding: utf-8 -*-

module HexaPDF

  # A general error.
  class Error < StandardError; end

  # Raised when the PDF is invalid and can't be read correctly.
  class MalformedPDFError < Error

    # The byte position in the PDF file where the error occured.
    attr_reader :pos

    # Creates a new malformed PDF error object for the given exception or exception message.
    #
    # The byte position where the error occured can be given via the optional +pos+ argument.
    def initialize(msg_or_error, pos: nil)
      super(msg_or_error)
      set_backtrace(msg_or_error.backtrace) if msg_or_error.kind_of?(Exception)
      @pos = pos
    end

    def message # :nodoc:
      pos_msg = @pos.nil? ? '' : " around position #{pos}"
      "PDF malformed#{pos_msg}: #{super}"
    end

  end

  # Raised when a PDF object contains invalid data.
  class InvalidPDFObjectError < Error; end

  # Raised when there are problems while encrypting or decrypting a document.
  class EncryptionError < Error; end

  # Raised when the encryption method is not supported.
  class UnsupportedEncryptionError < EncryptionError; end

end
