# -*- encoding: utf-8 -*-

require 'test_helper'
require 'hexapdf/pdf/encryption/standard_security_handler'
require 'hexapdf/pdf/document'
require 'hexapdf/pdf/writer'
require 'stringio'

describe HexaPDF::PDF::Encryption::StandardSecurityHandler do

  TEST_FILES = Dir[File.join(TEST_DATA_DIR, 'standard-security-handler', '*.pdf')].sort
  USER_PASSWORD = 'uhexapdf'
  OWNER_PASSWORD = 'ohexapdf'

  MINIMAL_PDF = File.join(TEST_DATA_DIR, 'minimal.pdf')
  MINIMAL_DOC = HexaPDF::PDF::Document.new(io: StringIO.new(File.read(MINIMAL_PDF)))

  TEST_FILES.each do |file|
    basename = File.basename(file)
    it "can decrypt, encrypt and decrypt the encrypted file #{basename} with the user password" do
      begin
        doc = HexaPDF::PDF::Document.new(io: StringIO.new(File.binread(file)),
                                         decryption_opts: {password: USER_PASSWORD})
        assert_equal(MINIMAL_DOC.trailer[:Info][:ModDate], doc.trailer[:Info][:ModDate])

        out = StringIO.new(''.b)
        HexaPDF::PDF::Writer.new(doc, out).write
        doc = HexaPDF::PDF::Document.new(io: out, decryption_opts: {password: USER_PASSWORD})
        assert_equal(MINIMAL_DOC.trailer[:Info][:ModDate], doc.trailer[:Info][:ModDate])
      rescue HexaPDF::EncryptionError => e
        flunk("Error processing #{basename}: #{e}")
      end
    end

    if basename !~ /\Auserpwd/
      it "can decrypt the encrypted file #{basename} with the owner password" do
        begin
          doc = HexaPDF::PDF::Document.new(io: StringIO.new(File.binread(file)),
                                           decryption_opts: {password: OWNER_PASSWORD})
          assert_equal(MINIMAL_DOC.trailer[:Info][:ModDate], doc.trailer[:Info][:ModDate])
        rescue HexaPDF::EncryptionError => e
          flunk("Error processing #{basename}: #{e}")
        end
      end
    end
  end


  before do
    @document = HexaPDF::PDF::Document.new
    @handler = HexaPDF::PDF::Encryption::StandardSecurityHandler.new(@document)
  end


  describe "prepare_encrypt_dict" do

    ALIAS = HexaPDF::PDF::Encryption::StandardSecurityHandler

    it "sets the trailer's /Encrypt entry to an encryption dictionary with a custom class" do
      @handler.set_up_encryption
      assert_kind_of(ALIAS::StandardEncryptionDictionary, @document.trailer[:Encrypt])
    end

    it "sets the correct revision independent /Filter value" do
      @handler.set_up_encryption
      assert_equal(:Standard, @document.trailer[:Encrypt][:Filter])
    end

    it "sets the correct revision independent /P value" do
      @handler.set_up_encryption
      assert_equal(ALIAS::Permissions::ALL|ALIAS::Permissions::RESERVED,
                   @document.trailer[:Encrypt][:P])
      @handler.set_up_encryption(permissions: ALIAS::Permissions::MODIFY_CONTENT)
      assert_equal(ALIAS::Permissions::MODIFY_CONTENT|ALIAS::Permissions::RESERVED,
                   @document.trailer[:Encrypt][:P])
    end

    it "sets the correct revision independent /EncryptMetadata value" do
      @handler.set_up_encryption
      assert(@document.trailer[:Encrypt][:EncryptMetadata])
      @handler.set_up_encryption(encrypt_metadata: false)
      refute(@document.trailer[:Encrypt][:EncryptMetadata])
    end

    it "sets the correct encryption dictionary values for revision 2 and 3" do
      arc4_assertions = lambda do |d|
        assert_equal(32, d[:U].length)
        assert_equal(32, d[:O].length)
        refute(d.value.key?(:UE))
        refute(d.value.key?(:OE))
        refute(d.value.key?(:Perms))
      end
      @handler.set_up_encryption(key_length: 40, algorithm: :arc4)
      dict = @document.trailer[:Encrypt]
      assert_equal(2, dict[:R])
      arc4_assertions.call(dict)

      @document.trailer.value.delete(:Encrypt)
      @handler.set_up_encryption(key_length: 128, algorithm: :arc4)
      dict = @document.trailer[:Encrypt]
      assert_equal(3, dict[:R])
      arc4_assertions.call(dict)
    end

    it "sets the correct encryption dictionary values for revisions 4 and 6" do
      crypt_filter = lambda do |d, r, alg, length|
        assert_equal(r, d[:R])
        assert_equal(alg == :AESV3 ? 48 : 32, d[:U].length)
        assert_equal(alg == :AESV3 ? 48 : 32, d[:O].length)
        assert_equal({CFM: alg, Length: length, AuthEvent: :DocOpen}, d[:CF][:StdCF])
        assert_equal(:StdCF, d[:StrF])
        assert_equal(:StdCF, d[:StmF])
        assert_equal(:StdCF, d[:EFF])
      end

      @handler.set_up_encryption(key_length: 128, algorithm: :arc4, force_V4: true)
      dict = @document.trailer[:Encrypt]
      refute(dict.value.key?(:UE))
      refute(dict.value.key?(:OE))
      refute(dict.value.key?(:Perms))
      crypt_filter.call(dict, 4, :V2, 16)

      @document.trailer.value.delete(:Encrypt)
      @handler.set_up_encryption(key_length: 128, algorithm: :aes)
      dict = @document.trailer[:Encrypt]
      refute(dict.value.key?(:UE))
      refute(dict.value.key?(:OE))
      refute(dict.value.key?(:Perms))
      crypt_filter.call(dict, 4, :AESV2, 16)

      @document.trailer.value.delete(:Encrypt)
      @handler.set_up_encryption(key_length: 256, algorithm: :aes)
      dict = @document.trailer[:Encrypt]
      assert_equal(32, dict[:UE].length)
      assert_equal(32, dict[:OE].length)
      assert_equal(16, dict[:Perms].length)
      crypt_filter.call(dict, 6, :AESV3, 32)
    end

  end


  describe "prepare_decryption" do

    it "fails if the /Filter value is incorrect" do
      exp = assert_raises(HexaPDF::UnsupportedEncryptionError) do
        @handler.set_up_decryption({Filter: :NonStandard, V: 2})
      end
      assert_match(/Invalid \/Filter/i, exp.message)
    end

    it "fails if the /R value is incorrect" do
      exp = assert_raises(HexaPDF::UnsupportedEncryptionError) do
        @handler.set_up_decryption({Filter: :Standard, V: 2, R: 5})
      end
      assert_match(/Invalid \/R/i, exp.message)
    end

    it "fails if the ID in the document's trailer is missing although it is needed" do
      exp = assert_raises(HexaPDF::EncryptionError) do
        @handler.set_up_decryption({Filter: :Standard, V: 2, R: 2})
      end
      assert_match(/Document ID/i, exp.message)
    end

    it "fails if the supplied password is invalid" do
      exp = assert_raises(HexaPDF::EncryptionError) do
        @handler.set_up_decryption({Filter: :Standard, V: 2, R: 6, U: 'a'*48, O: 'a'*48,
                                     UE: 'a'*32, OE: 'a'*32})
      end
      assert_match(/Invalid password/i, exp.message)
    end

  end

end
