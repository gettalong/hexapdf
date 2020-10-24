# -*- encoding: utf-8 -*-

require_relative 'common'
require 'hexapdf/encryption/aes'

describe HexaPDF::Encryption::AES do
  include EncryptionAlgorithmInterfaceTests

  before do
    @algorithm_class = Class.new do
      prepend HexaPDF::Encryption::AES

      attr_reader :key, :iv, :mode

      def initialize(key, iv, mode)
        @key, @iv, @mode = key, iv, mode
      end

      def process(data)
        raise "invalid data" if data.empty? || data.length % 16 != 0
        data
      end
    end

    @padding_data = (0..15).map do |length|
      {
        plain: '5' * length,
        cipher_padding: '5' * length + (16 - length).chr * (16 - length),
        length: 32,
      }
    end
    @padding_data << {plain: '5' * 16, cipher_padding: '5' * 16 + 16.chr * 16, length: 48}
  end

  describe "klass.encrypt/.decrypt" do
    it "returns the padded result with IV on klass.encrypt" do
      @padding_data.each do |data|
        result = @algorithm_class.encrypt('some key' * 2, data[:plain])
        assert_equal(data[:length], result.length)
        assert_equal(data[:cipher_padding][-16, 16], result[-16, 16])
      end
    end

    it "returns the decrypted result without padding and with IV removed on klass.decrypt" do
      @padding_data.each do |data|
        result = @algorithm_class.decrypt('some key' * 2, 'iv' * 8 + data[:cipher_padding])
        assert_equal(data[:plain], result)
      end
    end

    it "fails on decryption if not enough bytes are provided" do
      assert_raises(HexaPDF::EncryptionError) do
        @algorithm_class.decrypt('some' * 4, 'no iv')
      end
    end
  end

  describe "klass.encryption_fiber/.decryption_fiber" do
    before do
      @fiber = Fiber.new { Fiber.yield('first'); 'second' }
    end

    it "returns the padded result with IV on encryption_fiber" do
      @padding_data.each do |data|
        result = @algorithm_class.encryption_fiber('some key' * 2, Fiber.new { data[:plain] })
        result = TestHelper.collector(result)
        assert_equal(data[:length], result.length)
        assert_equal(data[:cipher_padding][-16, 16], result[-16, 16])
      end
    end

    it "returns the decrypted result without padding and with IV removed on decryption_fiber" do
      @padding_data.each do |data|
        result = @algorithm_class.decryption_fiber('some key' * 2,
                                                   Fiber.new { 'iv' * 8 + data[:cipher_padding] })
        result = TestHelper.collector(result)
        assert_equal(data[:plain], result)
      end
    end

    it "encryption works with multiple yielded strings" do
      f = Fiber.new { Fiber.yield('a' * 40); Fiber.yield('test'); "b" * 20 }
      result = TestHelper.collector(@algorithm_class.encryption_fiber('some key' * 2, f))
      assert_equal('a' * 40 << 'test' << 'b' * 20, result[16..-17])
    end

    it "decryption works with multiple yielded strings" do
      f = Fiber.new do
        Fiber.yield('iv' * 4)
        Fiber.yield('iv' * 4)
        Fiber.yield('a' * 20)
        Fiber.yield('a' * 20)
        8.chr * 8
      end
      result = TestHelper.collector(@algorithm_class.decryption_fiber('some key' * 2, f))
      assert_equal('a' * 40, result)
    end

    it "decryption works if the padding is invalid" do
      f = Fiber.new { 'a' * 32 }
      result = TestHelper.collector(@algorithm_class.decryption_fiber('some' * 4, f))
      assert_equal('a' * 16, result)

      f = Fiber.new { 'a' * 31 << "\x00" }
      result = TestHelper.collector(@algorithm_class.decryption_fiber('some' * 4, f))
      assert_equal('a' * 15 << "\x00", result)

      f = Fiber.new { 'a' * 29 << "\x00\x01\x03" }
      result = TestHelper.collector(@algorithm_class.decryption_fiber('some' * 4, f))
      assert_equal('a' * 13 << "\x00\x01\x03", result)
    end

    it "fails on decryption if not enough bytes are provided" do
      [4, 20, 40].each do |length|
        assert_raises(HexaPDF::EncryptionError) do
          TestHelper.collector(@algorithm_class.decryption_fiber('some' * 4,
                                                                 Fiber.new { 'a' * length }))
        end
      end
    end
  end

  it "does basic validation on initialization" do
    assert_raises(HexaPDF::EncryptionError) { @algorithm_class.new('t' * 7, '0' * 16, :encrypt) }
    assert_raises(HexaPDF::EncryptionError) { @algorithm_class.new('t' * 16, '0' * 7, :encrypt) }
    obj = @algorithm_class.new('t' * 16, 'i' * 16, 'encrypt')
    assert_equal(:encrypt, obj.mode)
  end
end
