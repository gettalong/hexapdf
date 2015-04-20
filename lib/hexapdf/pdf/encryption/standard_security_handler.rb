# -*- encoding: utf-8 -*-

require 'hexapdf/pdf/encryption/security_handler'
require 'digest/md5'
require 'digest/sha2'

module HexaPDF
  module PDF
    module Encryption

      # The password-based standard security handler of the PDF specification, identified by a
      # /Filter value of /Standard.
      #
      # == Overview
      #
      # The PDF specification defines one security handler that should be implemented by all PDF
      # conform libraries and applications. This standard security handler allows access permissions
      # and a user password as well as an owner password to be set.
      #
      # The access permissions (see Permissions) can be used to restrict what a user is allowed to
      # do with a PDF file.
      #
      # When a user or owner password is specified, a PDF file can only be opened when the correct
      # password is supplied.
      #
      # See: PDF1.7 s7.6.3, PDF2.0 s7.6.3
      class StandardSecurityHandler < SecurityHandler

        # The specialized encryption dictionary for the standard security handler.
        #
        # Contains additional fields that are used for storing the information needed for retrieving
        # the encryption key.
        class StandardEncryptionDictionary < EncryptionDictionary

          define_field :R, type: Integer, required: true
          define_field :O, type: PDFByteString, required: true
          define_field :OE, type: PDFByteString, version: '2.0'
          define_field :U, type: PDFByteString, required: true
          define_field :UE, type: PDFByteString, version: '2.0'
          define_field :P, type: Integer, required: true
          define_field :Perms, type: PDFByteString, version: '2.0'
          define_field :EncryptMetadata, type: Boolean, default: true, version: '1.5'

          define_validator(:validate_standard_encrypt_dict)

          private

          # Validates the fields special for this encryption dictionary.
          def validate_standard_encrypt_dict
            case value[:R]
            when 2, 3, 4
              if value[:U].length != 32 || value[:O].length != 32
                yield("Invalid size for /U or /O values for revisions <= 4", false)
              end
            when 6
              if !value.key?(:OE) || !value.key?(:UE) || !value.key?(:Perms)
                yield("Value of /OE, /UE or /Perms is missing for dictionary revision 6", false)
              end
              if value[:U].length != 48 || value[:O].length != 48 || value[:UE].length == 32 ||
                  value[:OE].length != 32 || value[:Perms].length != 16
                yield("Invalid size for /U, /O, /UE, /OE or /Perms values for revisions 6", false)
              end
            else
              yield("Value of /R is not one of 2, 3, 4 or 6", false)
            end
          end

        end

        # Defines all permissions that can be specified.
        #
        # It is possible to use an array of permission symbols instead of an integer to describe the
        # permission set. The used symbols are the lower case versions of the constants, i.e. the
        # symbol for MODIFY_CONSTANT would be :modify_constant.
        #
        # See: PDF1.7 s7.6.3.2
        module Permissions

          # Printing (if HIGH_QUALITY_PRINT is also set, then high quality printing is allowed)
          PRINT = 1 << 2

          # Modification of the content by operations that are different from those controller by
          # MODIFY_ANNOTATION, FILL_IN_FORMS and ASSEMBLE_DOCUMENT
          MODIFY_CONTENT = 1 << 3

          # Copying of content
          COPY_CONTENT = 1 << 4

          # Modifying annotations
          MODIFY_ANNOTATION = 1 << 5

          # Filling in form fields
          FILL_IN_FORMS = 1 << 8

          # Extracting content
          EXTRACT_CONTENT = 1 << 9

          # Assembling of the document (inserting, rotating or deleting of pages and creation of
          # bookmarks or thumbnail images)
          ASSEMBLE_DOCUMENT = 1 << 10

          # High quality printing
          HIGH_QUALITY_PRINT = 1 << 11

          # Allows everything
          ALL = PRINT | MODIFY_CONTENT | COPY_CONTENT | MODIFY_ANNOTATION | FILL_IN_FORMS |
            EXTRACT_CONTENT | ASSEMBLE_DOCUMENT | HIGH_QUALITY_PRINT

          # Reserved permission bits
          RESERVED = 0xFFFFF000

          # Maps permission symbols to their respective value
          SYMBOL_TO_PERMISSON = {
            :print => PRINT,
            :modify_content => MODIFY_CONTENT,
            :copy_content => COPY_CONTENT,
            :modify_annotation => MODIFY_ANNOTATION,
            :fill_in_forms => FILL_IN_FORMS,
            :extract_content => EXTRACT_CONTENT,
            :assemble_document => ASSEMBLE_DOCUMENT,
            :high_quality_print => HIGH_QUALITY_PRINT
          }

        end

        # Defines all possible options that can be passed to a StandardSecurityHandler when setting
        # up encryption.
        class EncryptionOptions

          # The user password. If this attribute is not specified but the virtual +password+
          # attribute is, then the latter is used.
          attr_accessor :user_password

          # The owner password. If this attribute is not specified but the virtual +password+
          # attribute is, then the latter is used.
          attr_accessor :owner_password

          # The permissions. Either an integer with the needed permission bits set or an array of
          # permission symbols.
          #
          # See: Permissions
          attr_accessor :permissions

          # The encryption algorithm.
          attr_accessor :algorithm

          # Specifies whether metadata should be encrypted.
          attr_accessor :encrypt_metadata

          # :nodoc:
          def initialize(data = {})
            fallback_pwd = data.delete(:password) { '' }
            @user_password = data.delete(:user_password) { fallback_pwd }
            @owner_password = data.delete(:owner_password) { fallback_pwd }
            @permissions = process_permissions(data.delete(:permissions) { Permissions::ALL })
            @algorithm = data.delete(:algorithm) { :arc4 }
            @encrypt_metadata = data.delete(:encrypt_metadata) { true }
            if data.size > 0
              raise HexaPDF::Error, "Invalid encryption options: #{data.keys.join(', ')}"
            end
          end

          private

          # Maps the permissions to an integer for use by the standard security handler.
          def process_permissions(perms)
            if perms.kind_of?(Array)
              perms = perms.inject(0) do |result, perm|
                result | Permissions::SYMBOL_TO_PERMISSON.fetch(perm, 0)
              end
            end
            Permissions::RESERVED | perms
          end

        end

        # Additionally checks that the document trailer's ID has not changed.
        #
        # See: SecurityHandler#encryption_key_valid?
        def encryption_key_valid?
          super && trailer_id_hash  == @trailer_id_hash
        end

        # Prepares the encryption dictionary for use in encrypting the document.
        #
        # See the attributes of the EncryptionOptions class for all possible arguments.
        def prepare_encrypt_dict(**kwoptions)
          options = EncryptionOptions.new(kwoptions)

          dict[:Filter] = :Standard
          dict[:R] = case dict[:V]
                     when 1 then 2
                     when 2 then 3
                     when 4 then 4
                     when 5 then 6
                     end
          dict[:EncryptMetadata] = options.encrypt_metadata
          dict[:P] = options.permissions

          if dict[:V] >= 4
            dict[:CF] = {
              StdCF: {
                CFM: if options.algorithm == :arc4
                       :V2
                     elsif key_length == 16
                       :AESV2
                     else
                       :AESV3
                     end,
                AuthEvent: :DocOpen,
                Length: key_length,
              }
            }
            dict[:StmF] = dict[:StrF] = dict[:EFF] = :StdCF
          end

          if dict[:R] <= 4 && !document.trailer[:ID].kind_of?(Array)
            document.trailer.set_random_id
          end

          options.user_password = prepare_password(options.user_password)
          options.owner_password = prepare_password(options.owner_password)

          dict[:O] = compute_o_field(options.owner_password, options.user_password)
          dict[:U] = compute_u_field(options.user_password)

          if dict[:R] <= 4
            encryption_key = compute_user_encryption_key(options.user_password)
          else
            encryption_key = random_bytes(32)
            dict[:UE] = compute_ue_field(options.user_password, encryption_key)
            dict[:OE] = compute_oe_field(options.owner_password, encryption_key)
            dict[:Perms] = compute_perms_field(encryption_key)
          end

          @trailer_id_hash = trailer_id_hash
          [encryption_key, options.algorithm, options.algorithm, options.algorithm]
        end

        # Uses the given password to retrieve the encryption key.
        def prepare_decryption(password: '')
          if dict[:Filter] != :Standard
            raise(HexaPDF::UnsupportedEncryptionError,
                  "Invalid /Filter value for standard security handler")
          elsif ![2, 3, 4, 6].include?(dict[:R])
            raise(HexaPDF::UnsupportedEncryptionError,
                  "Invalid /R value for standard security handler")
          elsif dict[:R] <= 4 && !document.trailer[:ID].kind_of?(Array)
            raise(HexaPDF::EncryptionError,
                  "Document ID for needed for decryption")
          end
          @trailer_id_hash = trailer_id_hash

          password = prepare_password(password)

          if user_password_valid?(prepare_password(''))
            encryption_key = compute_user_encryption_key(prepare_password(''))
          elsif user_password_valid?(password)
            encryption_key = compute_user_encryption_key(password)
          elsif owner_password_valid?(password)
            encryption_key = compute_owner_encryption_key(password)
          else
            raise HexaPDF::EncryptionError, "Invalid password specified"
          end

          encryption_key
        end

        private

        # Computes the hash value for the trailer ID array.
        def trailer_id_hash # :nodoc:
          document.unwrap(document.trailer[:ID]).hash
        end

        # See SecurityHandler#encryption_dictionary_class
        def encryption_dictionary_class
          StandardEncryptionDictionary
        end

        # The padding used for passwords with fewer than 32 bytes. Only used for revisions <= 4.
        #
        # See: PDF1.7 s7.6.3.3
        PASSWORD_PADDING = "\x28\xBF\x4E\x5E\x4E\x75\x8A\x41\x64\x00\x4E\x56\xFF\xFA\x01\x08" \
        "\x2E\x2E\x00\xB6\xD0\x68\x3E\x80\x2F\x0C\xA9\xFE\x64\x53\x69\x7A".b

        # Computes the user encryption key.
        #
        # For revisions <= 4 this is the *only* way for generating the encryption key needed to
        # encrypt or decrypt a file.
        #
        # For revision 6 the file encryption key is a string of random bytes that has been encrypted
        # with the user password. If the password is the owner password,
        # #compute_owner_encryption_key has to be used instead.
        #
        # See: PDF1.7 s7.6.3.3 (algorithm 2), PDF2.0 s7.6.3.3.2 (algorithm 2.A (a)-(b),(e))
        def compute_user_encryption_key(password)
          if dict[:R] <= 4
            data = password
            data += dict[:O]
            data << [dict[:P]].pack('V')
            data << document.trailer[:ID][0]
            data << [0xFFFFFFFF].pack('V') if dict[:R] == 4 && !dict[:EncryptMetadata]

            n = key_length
            data = Digest::MD5.digest(data)
            if dict[:R] >= 3
              50.times { data = Digest::MD5.digest(data[0, n]) }
            end

            data[0, n]
          elsif dict[:R] == 6
            key = compute_hash(password, dict[:U][40, 8])
            aes_algorithm.new(key, "\0"*16, :decrypt).process(dict[:UE])
          end
        end

        # Computes the owner encryption key.
        #
        # For revisions <= 4 this is done by first retrieving the user password through the use of
        # the owner password and then using the #compute_user_encryption_key method.
        #
        # For revision 6 file encryption key is a string of random bytes that has been encrypted
        # with the owner password. If the password is the user password,
        # #compute_user_encryption_key has to be used.
        #
        # See: PDF2.0 s7.6.3.3.2 (algorithm 2.A (a)-(d))
        def compute_owner_encryption_key(password)
          if dict[:R] <= 4
            compute_user_encryption_key(user_password_from_owner_password(password))
          elsif dict[:R] == 6
            key = compute_hash(password, dict[:O][40, 8], dict[:U])
            aes_algorithm.new(key, "\0"*16, :decrypt).process(dict[:OE])
          end
        end

        # Computes the encryption dictionary's /O (owner password) value.
        #
        # Short explanation: For revisions <= 4 the user password is encrypted with a key based on
        # the owner password. For revision 6 the /O value is a hash computed from the password and
        # the /U value with added validation and key salts.
        #
        # *Attention*: If revision 6 is used, the /U value has to be computed and set before this
        # method is used, otherwise the return value is incorrect!
        #
        # See: PDF1.7 s7.6.3.4 (algorithm 3), PDF2.0 s7.6.3.4.7 (algorithm 9 (a))
        def compute_o_field(owner_password, user_password)
          if dict[:R] <= 4
            data = Digest::MD5.digest(owner_password)
            if dict[:R] >= 3
              50.times { data = Digest::MD5.digest(data) }
            end
            key = data[0, key_length]

            data = arc4_algorithm.encrypt(key, user_password)
            if dict[:R] >= 3
              19.times {|i| data = arc4_algorithm.encrypt(xor_key(key, i + 1), data)}
            end

            data
          elsif dict[:R] == 6
            validation_salt = random_bytes(8)
            key_salt = random_bytes(8)
            compute_hash(owner_password, validation_salt, dict[:U]) << validation_salt << key_salt
          end
        end

        # Computes the encryption dictionary's /OE (owner encryption key) value (for revision 6
        # only).
        #
        # Short explanation: Encrypts the file encryption key with a key based on the password and
        # the /O and /U values.
        #
        # See: PDF2.0 s7.6.3.4.7 (algorithm 9 (b))
        def compute_oe_field(password, file_encryption_key)
          key = compute_hash(password, dict[:O][40, 8], dict[:U])
          aes_algorithm.new(key, "\0"*16, :encrypt).process(file_encryption_key)
        end

        # Computes the encryption dictionary's /U (user password) value.
        #
        # Short explanation: For revisions <= 4, the password padding string is encrypted with a key
        # based on the user password. For revision 6 the /U value is a hash computed from the
        # password with added validation and key salts.
        #
        # See: PDF1.7 s7.6.3.4 (algorithm 4 for R=2, algorithm 5 for R=3 and R=4)
        #      PDF2.0 s7.6.3.4.6 (algorithm 8 (a) for R=6)
        def compute_u_field(password)
          if dict[:R] == 2
            key = compute_user_encryption_key(password)
            arc4_algorithm.encrypt(key, PASSWORD_PADDING)
          elsif dict[:R] <= 4
            key = compute_user_encryption_key(password)
            data = Digest::MD5.digest(PASSWORD_PADDING + document.trailer[:ID][0])
            data = arc4_algorithm.encrypt(key, data)
            19.times {|i| data = arc4_algorithm.encrypt(xor_key(key, i + 1), data)}
            data << "hexapdfhexapdfhe"
          elsif dict[:R] == 6
            validation_salt = random_bytes(8)
            key_salt = random_bytes(8)
            compute_hash(password, validation_salt) << validation_salt << key_salt
          end
        end

        # Computes the encryption dictionary's /UE (user encryption key) value (for revision 6
        # only).
        #
        # Short explanation: Encrypts the file encryption key with a key based on the password and
        # the /U value.
        #
        # See: PDF2.0 s7.6.3.4.6 (algorithm 8 (b))
        def compute_ue_field(password, file_encryption_key)
          key = compute_hash(password, dict[:U][40, 8])
          aes_algorithm.new(key, "\0" * 16, :encrypt).process(file_encryption_key)
        end

        # Computes the encryption dictionary's /Perms (permissions) value (for revision 6 only).
        #
        # Uses /P and /EncryptMetadata values, so these have to be set beforehand.
        #
        # See: PDF2.0 s7.6.3.4.8 (algorithm 10)
        def compute_perms_field(file_encryption_key)
          data = [dict[:P]].pack('V')
          data << [0xFFFFFFFF].pack('V')
          data << (dict[:EncryptMetadata] ? 'T' : 'F')
          data << 'adb'
          data << 'hexa'
          aes_algorithm.new(file_encryption_key, "\0" * 16, :encrypt).process(data)
        end

        # Authenticates the user password, i.e. decides whether the given user password is valid.
        #
        # See: PDF1.7 s7.6.3.4 (algorithm 6), PDF2.0 s7.6.3.4.9 (algorithm 11)
        def user_password_valid?(password)
          if dict[:R] == 2
            compute_u_field(password) == dict[:U]
          elsif dict[:R] <= 4
            compute_u_field(password)[0, 16] == dict[:U][0, 16]
          elsif dict[:R] == 6
            compute_hash(password, dict[:U][32, 8]) == dict[:U][0, 32]
          end
        end

        # Authenticates the owner password, i.e. decides whether the given owner password is valid.
        #
        # See: PDF1.7 s7.6.3.4 (algorithm 7), PDF2.0 s7.6.3.4.10 (algorithm 12)
        def owner_password_valid?(password)
          if dict[:R] <= 4
            user_password_valid?(user_password_from_owner_password(password))
          elsif dict[:R] == 6
            compute_hash(password, dict[:O][32, 8], dict[:U]) == dict[:O][0, 32]
          end
        end

        # Returns the user password when given the owner password for revisions <= 4.
        #
        # See: PDF1.7 s7.6.3.4 (algorithm 7 (a) and (b))
        def user_password_from_owner_password(owner_password)
          data = Digest::MD5.digest(owner_password)
          if dict[:R] >= 3
            50.times { data = Digest::MD5.digest(data) }
          end
          key = data[0, key_length]

          if dict[:R] == 2
            userpwd = arc4_algorithm.decrypt(key, dict[:O])
          else
            userpwd = dict[:O]
            20.times {|i| userpwd = arc4_algorithm.decrypt(xor_key(key, 19 - i), userpwd)}
          end

          userpwd
        end

        # Computes a hash that is used extensively for all operations in security handlers of
        # revision 6.
        #
        # Note: The original input (as defined by the spec) is calculated as
        # "#{password}#{salt}#{user_key}" where +user_key+ has to be empty when doing operations
        # with the user password.
        #
        # See: PDF2.0 s7.6.3.3.3 (algorithm 2.B)
        def compute_hash(password, salt, user_key = '')
          k = Digest::SHA256.digest("#{password}#{salt}#{user_key}")
          e = ''

          i = 0
          while i < 64 || e.getbyte(-1) > i - 32
            k1 = "#{password}#{k}#{user_key}" * 64
            e = aes_algorithm.new(k[0, 16], k[16, 16], :encrypt).process(k1)
            k = case e.unpack('C16').inject(&:+) % 3  # 256 % 3 == 1 % 3 --> x*256 % 3 == x % 3
                when 0 then Digest::SHA256.digest(e)
                when 1 then Digest::SHA384.digest(e)
                when 2 then Digest::SHA512.digest(e)
                end
            i += 1
          end

          k[0, 32]
        end

        # Returns the password modified so that if follows certain rules:
        #
        # * For revisions <= 4, the password is converted into PDFDocEncoding, padded with
        #   PASSWORD_PADDING and truncated to a maximum of 32 bytes.
        #
        # * For revision 6 the password is converted into UTF-8 encoding that is normalized
        #   according to the PDF2.0 specification.
        #
        # See: PDF1.7 s7.6.3.3 (algorithm 2 step a)),
        #      PDF2.0 s7.6.3.3.2 (algorithm 2.A steps a) and b))
        def prepare_password(password)
          if dict[:R] <= 4
            password.to_s[0, 32].ljust(32, PASSWORD_PADDING).force_encoding(Encoding::BINARY)
          elsif dict[:R] == 6
            password.to_s.encode(Encoding::UTF_8).force_encoding(Encoding::BINARY)[0, 127]
          end
        end

        # XORs each byte of the String +key+ with value and returns the resulting string.
        def xor_key(key, value)
          new_key = key.dup
          i = 0
          (new_key.setbyte(i, new_key.getbyte(i) ^ value); i += 1) while i < new_key.length
          new_key
        end

      end

    end
  end
end
