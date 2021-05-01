# -*- encoding: utf-8 -*-

require 'test_helper'
require 'hexapdf/encryption/standard_security_handler'
require 'hexapdf/document'
require 'hexapdf/writer'
require 'stringio'

describe HexaPDF::Encryption::StandardEncryptionDictionary do
  before do
    @document = HexaPDF::Document.new
    @dict = HexaPDF::Encryption::StandardEncryptionDictionary.new({}, document: @document)
    @dict[:Filter] = :Standard
    @dict[:V] = 1
    @dict[:R] = 2
    @dict[:U] = 'test' * 8
    @dict[:O] = 'test' * 8
    @dict[:P] = -5
    @dict[:UE] = 'test' * 8
    @dict[:OE] = 'test' * 8
    @dict[:Perms] = 'test' * 8
  end

  it "validates the /R value" do
    @dict[:R] = 2
    assert(@dict.validate)
    @dict[:R] = 5
    refute(@dict.validate)
  end

  [:U, :O].each do |field|
    it "validates the length of /#{field} field for R <= 4" do
      @dict[field] = 'test'
      refute(@dict.validate)
    end
  end

  [:U, :O, :UE, :OE, :Perms].each do |field|
    it "validates the length of /#{field} field for R=6" do
      @dict[:R] = 6
      @dict[field] = 'test'
      refute(@dict.validate)
    end
  end

  [:UE, :OE, :Perms].each do |field|
    it "validates the existence of the /#{field} field for R=6" do
      @dict[:R] = 6
      @dict.delete(field)
      refute(@dict.validate)
    end
  end
end

describe HexaPDF::Encryption::StandardSecurityHandler do
  test_files = Dir[File.join(TEST_DATA_DIR, 'standard-security-handler', '*.pdf')].sort
  user_password = 'uhexapdf'
  owner_password = 'ohexapdf'

  minimal_doc = HexaPDF::Document.new(io: StringIO.new(MINIMAL_PDF))

  test_files.each do |file|
    basename = File.basename(file)
    it "can decrypt, encrypt and decrypt the encrypted file #{basename} with the user password" do
      begin
        doc = HexaPDF::Document.new(io: StringIO.new(File.binread(file)),
                                    decryption_opts: {password: user_password})
        assert_equal(minimal_doc.trailer[:Info][:ModDate], doc.trailer[:Info][:ModDate])

        out = StringIO.new(''.b)
        HexaPDF::Writer.new(doc, out).write
        doc = HexaPDF::Document.new(io: out, decryption_opts: {password: user_password})
        assert_equal(minimal_doc.trailer[:Info][:ModDate], doc.trailer[:Info][:ModDate])
      rescue HexaPDF::EncryptionError => e
        flunk("Error processing #{basename}: #{e}")
      end
    end

    unless basename.start_with?("userpwd")
      it "can decrypt the encrypted file #{basename} with the owner password" do
        begin
          doc = HexaPDF::Document.new(io: StringIO.new(File.binread(file)),
                                      decryption_opts: {password: owner_password})
          assert_equal(minimal_doc.trailer[:Info][:ModDate], doc.trailer[:Info][:ModDate])
        rescue HexaPDF::EncryptionError => e
          flunk("Error processing #{basename}: #{e}")
        end
      end
    end
  end

  before do
    @document = HexaPDF::Document.new
    @handler = HexaPDF::Encryption::StandardSecurityHandler.new(@document)
  end

  it "can encrypt and then decrypt with all encryption variations" do
    {arc4: [40, 48, 128], aes: [128, 256]}.each do |algorithm, key_lengths|
      key_lengths.each do |key_length|
        begin
          doc = HexaPDF::Document.new
          doc.encrypt(algorithm: algorithm, key_length: key_length)
          sio = StringIO.new
          doc.write(sio)
          doc = HexaPDF::Document.new(io: sio)
          assert_kind_of(Time, doc.trailer.info[:ModDate], "alg: #{algorithm} #{key_length} bits")
        rescue HexaPDF::Error => e
          flunk("Error using variation: #{algorithm} #{key_length} bits\n" << e.message)
        end
      end
    end
  end

  describe "prepare_encryption" do
    it "returns the encryption dictionary wrapped with a custom class" do
      dict = @handler.set_up_encryption
      assert_kind_of(HexaPDF::Encryption::StandardEncryptionDictionary, dict)
    end

    it "sets the correct revision independent /Filter value" do
      dict = @handler.set_up_encryption
      assert_equal(:Standard, dict[:Filter])
    end

    it "sets the correct revision independent /P value" do
      dict = @handler.set_up_encryption
      assert_equal(@handler.class::Permissions::ALL | \
                   @handler.class::Permissions::RESERVED - 2**32,
                   dict[:P])
      dict = @handler.set_up_encryption(permissions: @handler.class::Permissions::COPY_CONTENT)
      assert_equal(@handler.class::Permissions::COPY_CONTENT | \
                   @handler.class::Permissions::RESERVED - 2**32,
                   dict[:P])
      dict = @handler.set_up_encryption(permissions: [:modify_content, :modify_annotation])
      assert_equal(@handler.class::Permissions::MODIFY_CONTENT | \
                   @handler.class::Permissions::MODIFY_ANNOTATION | \
                   @handler.class::Permissions::RESERVED - 2**32,
                   dict[:P])
    end

    it "sets the correct revision independent /EncryptMetadata value" do
      dict = @handler.set_up_encryption
      assert(dict[:EncryptMetadata])
      dict = @handler.set_up_encryption(encrypt_metadata: false)
      refute(dict[:EncryptMetadata])
    end

    it "sets the correct encryption dictionary values for revision 2 and 3" do
      arc4_assertions = lambda do |d|
        assert_equal(32, d[:U].length)
        assert_equal(32, d[:O].length)
        refute(d.value.key?(:UE))
        refute(d.value.key?(:OE))
        refute(d.value.key?(:Perms))
      end
      dict = @handler.set_up_encryption(key_length: 40, algorithm: :arc4)
      assert_equal(2, dict[:R])
      arc4_assertions.call(dict)

      dict = @handler.set_up_encryption(key_length: 128, algorithm: :arc4)
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
      end

      dict = @handler.set_up_encryption(key_length: 128, algorithm: :arc4, force_v4: true)
      refute(dict.value.key?(:UE))
      refute(dict.value.key?(:OE))
      refute(dict.value.key?(:Perms))
      crypt_filter.call(dict, 4, :V2, 16)

      dict = @handler.set_up_encryption(key_length: 128, algorithm: :aes)
      refute(dict.value.key?(:UE))
      refute(dict.value.key?(:OE))
      refute(dict.value.key?(:Perms))
      crypt_filter.call(dict, 4, :AESV2, 16)

      dict = @handler.set_up_encryption(key_length: 256, algorithm: :aes)
      assert_equal(32, dict[:UE].length)
      assert_equal(32, dict[:OE].length)
      assert_equal(16, dict[:Perms].length)
      crypt_filter.call(dict, 6, :AESV3, 32)
    end

    it "uses the password keyword as fallback, the user password as owner password if necessary" do
      dict1 = @handler.set_up_encryption(password: 'user', owner_password: 'owner')
      dict2 = @handler.set_up_encryption(password: 'owner', user_password: 'user')
      dict3 = @handler.set_up_encryption(user_password: 'user', owner_password: 'owner')
      dict4 = @handler.set_up_encryption(user_password: 'test', owner_password: 'test')
      dict5 = @handler.set_up_encryption(user_password: 'test')

      assert_equal(dict1[:U], dict2[:U])
      assert_equal(dict2[:U], dict3[:U])
      assert_equal(dict1[:O], dict2[:O])
      assert_equal(dict2[:O], dict3[:O])
      assert_equal(dict4[:O], dict5[:O])
    end

    it "fails if the password contains invalid characters" do
      assert_raises(HexaPDF::EncryptionError) { @handler.set_up_encryption(password: 'œ test') }
    end

    it "fails for unknown keywords" do
      assert_raises(ArgumentError) { @handler.set_up_encryption(unknown: 'test') }
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
        @handler.set_up_decryption({Filter: :Standard, V: 2, R: 6, U: 'a' * 48, O: 'a' * 48,
                                    UE: 'a' * 32, OE: 'a' * 32})
      end
      assert_match(/Invalid password/i, exp.message)
    end

    describe "/Perms field checking" do
      before do
        @dict = @handler.set_up_encryption(key_length: 256, algorithm: :aes)
      end

      it "fails if the field cannot be decrypted" do
        @dict[:Perms].succ!
        exp = assert_raises(HexaPDF::EncryptionError) { @handler.set_up_decryption(@dict) }
        assert_match(/cannot be decrypted/, exp.message)
      end

      it "fails if the /P field doesn't match" do
        @dict[:P] = 500
        exp = assert_raises(HexaPDF::EncryptionError) { @handler.set_up_decryption(@dict) }
        assert_match(/\/P/, exp.message)
      end

      it "fails if the /EncryptMetadata field doesn't match" do
        @dict[:EncryptMetadata] = false
        exp = assert_raises(HexaPDF::EncryptionError) { @handler.set_up_decryption(@dict) }
        assert_match(/\/EncryptMetadata/, exp.message)
      end

      it "ignores the /Perms when requested" do
        obj = HexaPDF::Object.new(nil, oid: 1)
        obj.value = @handler.encrypt_string('test', obj)

        @dict[:P] = 500
        @handler.set_up_decryption(@dict, check_permissions: false)
        assert_equal('test', @handler.decrypt(obj).value)
      end
    end
  end

  it "encryption key stays valid even if default dict values are set while setting up decryption" do
    @document.encrypt(key_length: 128, algorithm: :aes)
    assert(@document.security_handler.encryption_key_valid?)

    @document.trailer[:Encrypt].delete(:EncryptMetadata)
    handler = HexaPDF::Encryption::SecurityHandler.set_up_decryption(@document)
    assert(handler.encryption_key_valid?)
  end

  it "returns an array of permission symbols" do
    perms = @handler.class::Permissions::MODIFY_CONTENT | @handler.class::Permissions::COPY_CONTENT
    @handler.set_up_encryption(permissions: perms)
    assert_equal([:copy_content, :modify_content], @handler.permissions.sort)
  end

  describe "handling of metadata streams" do
    before do
      @doc = HexaPDF::Document.new
      @output = StringIO.new(''.b)
    end

    it "doesn't decrypt or encrypt a metadata stream if /EncryptMetadata is false" do
      @doc.encrypt(encrypt_metadata: false)
      @doc.catalog[:Metadata] = @doc.wrap({Type: :Metadata, Subtype: :XML}, stream: "HELLODATA")
      @doc.write(@output)
      assert_match(/stream\nHELLODATA\nendstream/, @output.string)

      doc = HexaPDF::Document.new(io: @output)
      assert_equal('HELLODATA', doc.catalog[:Metadata].stream)
    end

    it "doesn't modify decryption/encryption for metadata streams if /V is not 4 or 5" do
      @doc.encrypt(encrypt_metadata: false, algorithm: :arc4)
      @doc.catalog[:Metadata] = @doc.wrap({Type: :Metadata, Subtype: :XML}, stream: "HELLODATA")
      @doc.write(@output)
      refute_match(/stream\nHELLODATA\nendstream/, @output.string)

      doc = HexaPDF::Document.new(io: @output)
      assert_equal('HELLODATA', doc.catalog[:Metadata].stream)
    end
  end
end
