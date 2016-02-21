# -*- encoding: utf-8 -*-

module HexaPDF
  module Encryption

    # Common interface for ARC4 algorithms
    #
    # This module defines the common interface that is used by the security handlers to encrypt or
    # decrypt data with ARC4. It has to be *prepended* by any ARC4 algorithm class.
    #
    # See the ClassMethods module for available class level methods of ARC4 algorithms.
    #
    # == Implementing an ARC4 Class
    #
    # An ARC4 class needs to define at least the following methods:
    #
    # initialize(key)::
    #   Initializes the ARC4 algorithm with the given key.
    #
    # process(data)::
    #   Processes the data and returns the encrypted/decrypted data. Since the ARC4 algorithm is
    #   symmetric in regards to its inner workings, the same method can be used for encryption and
    #   decryption.
    module ARC4

      # Convenience methods for decryption and encryption that operate according to the PDF
      # specification.
      #
      # These methods will be available on the class object that prepends the ARC4 module.
      module ClassMethods

        # Encrypts the given +data+ with the +key+.
        #
        # See: PDF1.7 s7.6.2.
        def encrypt(key, data)
          new(key).process(data)
        end
        alias :decrypt :encrypt

        # Returns a Fiber object that encrypts the data from the given source fiber with the
        # +key+.
        def encryption_fiber(key, source)
          Fiber.new do
            algorithm = new(key)
            while source.alive? && (data = source.resume)
              Fiber.yield(algorithm.process(data)) unless data.empty?
            end
          end
        end
        alias :decryption_fiber :encryption_fiber

      end

      # Automatically extends the klass with the necessary class level methods.
      def self.prepended(klass) # :nodoc:
        klass.extend(ClassMethods)
      end

    end

  end
end
