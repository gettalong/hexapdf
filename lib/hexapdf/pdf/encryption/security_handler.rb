# -*- encoding: utf-8 -*-

require 'digest/md5'
require 'hexapdf/error'
require 'hexapdf/pdf/dictionary'
require 'hexapdf/pdf/stream'

module HexaPDF
  module PDF
    module Encryption

      # Base class for all security handlers.
      #
      # == Implementing a Security Handler
      #
      # Each security handler has to implement the following methods:
      #
      # prepare_encrypt_dict(**options)::
      #   Prepares the encryption dictionary for use in encrypting the document and later for
      #   decryption.
      #
      #   See the #set_up_encryption documentation for information on which options are passed on to
      #   this method.
      #
      #   Returns the encryption key as well as the string, stream and embedded file algorithms.
      #
      # prepare_decryption(**options)::
      #   Prepares the security handler for decryption by using the information from the document's
      #   encryption dictionary as well as the provided arguments.
      #
      #   See the #set_up_decryption documentation for additional information.
      #
      #   Returns the encryption key that should be used for decryption.
      #
      # Additionally, the following methods can be overridden to provide a more specific meaning:
      #
      # encryption_dictionary_class::
      #   Returns the class that is used for the encryption dictionary. Should be derived from the
      #   EncryptionDictionary class.
      #
      # initialize(document)::
      #   Creates a new security handler object for the given Document.
      class SecurityHandler

        # Base class for all encryption dictionaries.
        #
        # Contains entries common to all encryption dictionaries. If a specific security handler
        # needs further fields it should derive a new subclass and add the new fields there.
        #
        # See: PDF1.7 s7.6.1
        class EncryptionDictionary < Dictionary

          define_field :Filter, type: Symbol, required: true
          define_field :SubFilter, type: Symbol, version: '1.3'
          define_field :V, type: Integer, required: true
          define_field :Lenth, type: Integer, default: 40, version: '1.4'
          define_field :CF, type: Dictionary, version: '1.5'
          define_field :StmF, type: Symbol, default: :Identity, version: '1.5'
          define_field :StrF, type: Symbol, default: :Identity, version: '1.5'
          define_field :EFF, type: Symbol, version: '1.6'

        end

        # Sets up the security handler that is used for decrypting the given document and modifies
        # the document so that the decryption is handled automatically behind the scenes. The
        # decryption handler is also returned.
        #
        # The +decryption_opts+ contain decryption options specific to the security handler that is
        # used by the PDF file.
        def self.set_up_decryption(document, **decryption_opts)
          dict = document.unwrap(document.trailer[:Encrypt])
          handler = document.config['encryption.filter_map'][dict[:Filter]]
          handler = document.config['encryption.sub_filter_map'][dict[:SubFilter]] unless handler
          handler = ::Object.const_get(handler) if handler.kind_of?(String)

          handler = handler.new(document)
          handler.set_up_decryption(dict, **decryption_opts)
          document.revisions.each do |r|
            loader = r.loader
            r.loader = lambda do |xref_entry|
              obj = loader.call(xref_entry)
              xref_entry.compressed? ? obj : handler.decrypt(obj)
            end
          end

          handler
        end

        # The associated PDF document.
        attr_reader :document

        # Creates a new SecurityHandler for the given document.
        def initialize(document)
          @document = document
          @encrypt_dict_hash = nil
        end

        # Checks if the encryption key computed by this security handler is derived from the
        # documents encryption dictionary.
        def encryption_key_valid?
          document.unwrap(document.trailer[:Encrypt]).hash == @encrypt_dict_hash
        end

        # Updates the document's encryption dictionary with all needed values so that the document
        # can later be decrypted and sets the encryption key and algorithms for encrypting the
        # document.
        #
        # The security handler specific +options+ as well as the +algorithm+ arguments are passed
        # on to the #prepare_encrypt_dict method.
        #
        # Options for all security handlers:
        #
        # key_length::
        #   The key length in bits. Possible values are in the range of 40 to 128 and 256 and it
        #   needs to be divisible by 8.
        #
        # algorithm::
        #   The encryption algorithm. Possible values are :arc4 for ARC4 encryption with key lengths
        #   of 40 to 128 bit or :aes for AES encryption with key lengths of 128 or 256 bit.
        #
        # force_V4::
        #   Forces the use of protocol version 4 when key_length=128 and algorithm=:arc4.
        #
        # See: PDF1.7 s7.6.1, PDF2.0 s7.6.1
        def set_up_encryption(key_length: 128, algorithm: :arc4, force_V4: false, **options)
          @dict = document.trailer[:Encrypt] =
            encryption_dictionary_class.new({}, document: document)

          dict[:V] =
            case key_length
            when 40
              1
            when 48, 56, 64, 72, 80, 88, 96, 104, 112, 120
              2
            when 128
              (algorithm == :aes || force_V4 ? 4 : 2)
            when 256
              5
            else
              raise(HexaPDF::UnsupportedEncryptionError,
                    "Invalid key length #{key_length} specified")
            end
          dict[:Length] = key_length if dict[:V] == 2

          if ![:aes, :arc4].include?(algorithm)
            raise(HexaPDF::UnsupportedEncryptionError,
                  "Unsupported encryption algorithm: #{algorithm}")
          elsif key_length < 128 && algorithm == :aes
            raise(HexaPDF::UnsupportedEncryptionError,
                  "AES algorithm needs a key length of 128 or 256 bit")
          elsif key_length == 256 && algorithm == :arc4
            raise(HexaPDF::UnsupportedEncryptionError,
                  "ARC4 algorithm can only be used with key lengths between 40 and 128 bit")
          end

          result = prepare_encrypt_dict(algorithm: algorithm, **options)
          @encrypt_dict_hash = dict.value.hash
          set_up_security_handler(*result)
        end

        # Uses the encryption dictionary to set up the security handler for decrypting the document.
        #
        # The security handler specific +options+ are passed on to the #prepare_decryption method.
        #
        # See: PDF1.7 s7.6.1, PDF2.0 s7.6.1
        def set_up_decryption(dictionary, **options)
          @dict = encryption_dictionary_class.new(dictionary, document: document)
          @encrypt_dict_hash = dict.value.hash

          case dict[:V]
          when 1, 2
            strf = stmf = eff = :arc4
          when 4, 5
            strf, stmf, eff = [:StrF, :StmF, :EFF].map do |alg|
              if dict[:CF] && (cf_dict = dict[:CF][dict[alg]])
                case cf_dict[:CFM]
                when :V2 then :arc4
                when :AESV2, :AESV3 then :aes
                when :None then :identity
                else
                  raise(HexaPDF::UnsupportedEncryptionError,
                        "Unsupported encryption method: #{cf_dict[:CFM]}")
                end
              else
                :identity
              end
            end
            eff = stmf unless dict[:EFF]
          else
            raise HexaPDF::UnsupportedEncryptionError, "Unsupported encryption version #{dict[:V]}"
          end

          set_up_security_handler(prepare_decryption(**options), strf, stmf, eff)
        end

        # Decrypts the strings and the possibly attached stream of the given indirect object in
        # place.
        #
        # See: PDF1.7 s7.6.2
        def decrypt(obj)
          return obj if obj == document.trailer[:Encrypt] ||
            (obj.value.kind_of?(Hash) && obj.value[:Type] == :XRef)

          key = object_key(obj.oid, obj.gen, string_algorithm)
          each_string_in_object(obj.value) do |str|
            next if str.empty?
            str.replace(string_algorithm.decrypt(key, str))
          end

          if obj.kind_of?(HexaPDF::PDF::Stream)
            unless string_algorithm == stream_algorithm
              key = object_key(obj.oid, obj.gen, stream_algorithm)
            end
            obj.raw_stream.source = stream_algorithm.decryption_fiber(key, obj.stream_source)
          end

          obj
        end

        # Returns the encrypted version of the string that resides in the given indirect object.
        #
        # See: PDF1.7 s7.6.2
        def encrypt_string(str, obj)
          return str if str.empty? || obj == document.trailer[:Encrypt] ||
            (obj.value.kind_of?(Hash) && obj.value[:Type] == :XRef)

          key = object_key(obj.oid, obj.gen, string_algorithm)
          string_algorithm.encrypt(key, str)
        end

        # Returns a Fiber that encrypts the contents of the given stream object.
        def encrypt_stream(obj)
          return obj.stream_encoder if obj.value[:Type] == :XRef

          key = object_key(obj.oid, obj.gen, stream_algorithm)
          stream_algorithm.encryption_fiber(key, obj.stream_encoder)
        end

        private

        # Returns the encryption dictionary used by this security handler.
        #
        # Subclasses should use this dictionary to read and set values.
        def dict
          @dict
        end

        # Returns the encryption key that is used for encryption/decryption.
        #
        # Only available after decryption or encryption has been set up.
        def encryption_key
          @encryption_key
        end

        # Returns the algorithm class that is used for encrypting/decrypting strings.
        #
        # Only available after decryption or encryption has been set up.
        def string_algorithm
          @string_algorithm
        end

        # Returns the algorithm class that is used for encrypting/decrypting streams.
        #
        # Only available after decryption or encryption has been set up.
        def stream_algorithm
          @stream_algorithm
        end

        # Returns the algorithm class that is used for encrypting/decrypting embedded files.
        #
        # Only available after decryption or encryption has been set up.
        def embedded_file_algorithm
          @embedded_file_algorithm
        end

        # Assigns all necessary attributes so that encryption/decryption works correctly.
        #
        # The assigned values can be retrieved via the #encryption_key, #string_algorithm,
        # #stream_algorithm and #embedded_file_algorithm methods.
        def set_up_security_handler(key, strf, stmf, eff)
          @encryption_key = key
          @string_algorithm = send("#{strf}_algorithm")
          @stream_algorithm = send("#{stmf}_algorithm")
          @embedded_file_algorithm = send("#{eff}_algorithm")
        end

        # Returns the class that is used for ARC4 encryption.
        def arc4_algorithm
          @arc4_algorithm ||= ::Object.const_get(document.config['encryption.arc4'])
        end

        # Returns the class that is used for AES encryption.
        def aes_algorithm
          @aes_algorithm ||= ::Object.const_get(document.config['encryption.aes'])
        end

        # Returns the class that is used for the identity algorithm which passes back the data as is
        # without encrypting or decrypting it.
        def identity_algorithm
          Identity
        end

        # Computes the key for decrypting the indirect object with the given algorithm.
        #
        # See: PDF1.7 s7.6.2 (algorithm 1), PDF2.0 s7.6.2.2 (algorithm 1.A)
        def object_key(oid, gen, algorithm)
          key = encryption_key
          return key if dict[:V] == 5

          key += [oid].pack('V')[0, 3] << [gen].pack('v')
          key << "sAlT" if algorithm.ancestors.include?(AES)
          n_plus_5 = key_length + 5
          Digest::MD5.digest(key)[0, (n_plus_5 > 16 ? 16 : n_plus_5)]
        end

        # Returns the length of the encryption key in bytes based on the security handlers version.
        #
        # See: PDF1.7 s7.6.1, PDF2.0 s7.6.1
        def key_length
          case dict[:V]
          when 1 then 5
          when 2 then dict[:Length] / 8
          when 4 then 16 # PDF2.0 s7.6.1 specifies that a /V of 4 is equal to length of 128bit
          when 5 then 32 # PDF2.0 s7.6.1 specifies that a /V of 5 is equal to length of 256bit
          end
        end

        # Returns the class used as wrapper for the encryption dictionary.
        def encryption_dictionary_class
          EncryptionDictionary
        end

        # Returns +n+ random bytes.
        def random_bytes(n)
          aes_algorithm.random_bytes(n)
        end

        # Finds all strings in the given object and yields them.
        #
        # Note: Decryption happens directly after parsing and loading an object, before it can be
        # touched by anthing else. Therefore we only have to contend with the basic data structures.
        def each_string_in_object(obj, &block) # :yields: str
          case obj
          when Hash
            obj.each {|key, val| each_string_in_object(val, &block)}
          when Array
            obj.each {|inner_o| each_string_in_object(inner_o, &block)}
          when String
            yield(obj)
          end
        end

      end

    end
  end
end
