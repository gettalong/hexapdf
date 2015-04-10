# -*- encoding: utf-8 -*-

module HexaPDF
  module PDF

    # == Overview
    #
    # A PDF document may be encrypted so that
    #
    # * certain permissions are respected when the document is opened,
    # * a password must be specified so that a document can be openend or so that
    # * a password must be specified to remove the restrictions and allow full access.
    #
    # This module contains all encryption and security related code to facilitate PDF encryption.
    #
    #
    # === Security Handlers
    #
    # Security handlers manage the process of encrypting and decrypting a PDF document. One of the
    # main responsibilities of them is providing the encryption key that is then used by the
    # selected encryption algorithm (see below). However, security handlers may also provide
    # additional information.
    #
    # The SecurityHandler is the base class for all such security handlers. It defines the interface
    # and all common code for encrypting and decrypting strings and streams.
    #
    # The PDF specification also defines a password-based standard security handler that
    # additionally allows setting permission information. This security handler is implemented by
    # the StandardSecurityHandler class.
    #
    #
    # === Encryption Algorithms
    #
    # PDF security is based on two algorithms with varying key lengths: ARC4 and AES. The ARC4 and
    # AES modules contain code common to their specific algorithm and are adapted to work together
    # with any SecurityHandler.
    #
    # There are at least two versions of each algorithm present:
    #
    # FastAES and FastARC4::
    #   The preferred versions which are based on OpenSSL and therefore rely on the OpenSSL library
    #   and a C extension.
    #
    # RubyAES and RubyARC4::
    #   Pure Ruby implementations of the algorithms which are naturally much slower than the OpenSSL
    #   based ones. However, these implementation can be used on any Ruby implementation.
    #
    #
    # See: PDF1.7 s7.6
    module Encryption

      autoload(:ARC4, 'hexapdf/pdf/encryption/arc4')
      autoload(:AES, 'hexapdf/pdf/encryption/aes')
      autoload(:FastARC4, "hexapdf/pdf/encryption/fast_arc4")
      autoload(:RubyARC4, "hexapdf/pdf/encryption/ruby_arc4")
      autoload(:FastAES, "hexapdf/pdf/encryption/fast_aes")
      autoload(:RubyAES, "hexapdf/pdf/encryption/ruby_aes")
      autoload(:Identity, "hexapdf/pdf/encryption/identity")

      autoload(:SecurityHandler, 'hexapdf/pdf/encryption/security_handler')
      autoload(:StandardSecurityHandler, 'hexapdf/pdf/encryption/standard_security_handler')

    end
  end
end
