# -*- encoding: utf-8 -*-

require 'test_helper'
require 'hexapdf/pdf/encryption/aes'

module AESEncryptionTests

  TEST_VECTOR_FILES = Dir[File.join(__dir__, '..', '..', '..', 'data', 'aes-test-vectors', '*')]

  def test_processes_the_AES_test_vectors
    TEST_VECTOR_FILES.each do |filename|
      name, size, mode = File.basename(filename, '.data.gz').split('-')
      size = size.to_i / 8
      data = Zlib::GzipReader.open(filename) {|io| io.read}.force_encoding(Encoding::BINARY)
      data.scan(/(.{#{size}})(.{16})(.{16})(.{16})/m).each_with_index do |(key, iv, plain, cipher), index|
        aes = @algorithm_class.new(key, iv, mode.intern)
        assert_equal(cipher, aes.process(plain),
                     "name: #{name}, size: #{size*8}, mode: #{mode}, index: #{index}")
      end
    end
  end

  def test_can_accept_one_big_chunk_or_multiple_smaller_ones
    big = @algorithm_class.new('t'*16, '0'*16, :encrypt)
    small = @algorithm_class.new('t'*16, '0'*16, :encrypt)
    assert_equal(big.process('some'*16),
                 small.process('some'*8) << small.process('some'*4) << small.process('some'*4))
  end

  def test_raises_error_on_invalid_key_length
    assert_raises(HexaPDF::Error) { @algorithm_class.new('t'*7, '0'*16, :encrypt) }
  end

  def test_raises_error_on_invalid_iv_length
    assert_raises(HexaPDF::Error) { @algorithm_class.new('t'*16, '0'*7, :encrypt) }
  end

end


describe HexaPDF::PDF::Encryption::AES do

  before do
    @test_class = Class.new do
      prepend HexaPDF::PDF::Encryption::AES

      attr_reader :key, :iv, :mode

      def initialize(key, iv, mode)
        @key, @iv, @mode = key, iv, mode
      end

      def process(data)
        data
      end

    end
  end

  it "extends the class object with the necessary methods" do
    assert_respond_to(@test_class, :encrypt)
    assert_respond_to(@test_class, :decrypt)
  end

  describe "padding and IV on klass.encrypt/.decrypt" do

    before do
      @data = (0..15).map do |length|
        {plain: '5'*length, cipher_padding: '5'*length + (16-length).chr * (16-length), length: 32}
      end
      @data << {plain: '5'*16, cipher_padding: '5'*16 + 16.chr * 16, length: 48}
    end

    it "returns the padded result with IV on klass.encrypt" do
      @data.each do |data|
        result = @test_class.encrypt('some key'*2, data[:plain])
        assert_equal(data[:length], result.length)
        assert_equal(data[:cipher_padding][-16, 16], result[-16, 16])
      end
    end

    it "returns the decrypted result without padding and with IV removed on klass.decrypt" do
      @data.each do |data|
        result = @test_class.decrypt('some key'*2, 'iv'*8 + data[:cipher_padding])
        assert_equal(data[:plain], result)
      end
    end

    it "fails on decryption if the padding is invalid" do
      assert_raises(HexaPDF::Error) { @test_class.decrypt('some'*4, 'iv'*8 + 'somedata'*4) }
    end

    it "fails on decryption if not enough bytes are provided" do
      assert_raises(HexaPDF::Error) { @test_class.decrypt('some'*4, 'no iv') }
    end

  end

  it "does basic validation on initialization" do
    assert_raises(HexaPDF::Error) { @test_class.new('t'*7, '0'*16, :encrypt) }
    assert_raises(HexaPDF::Error) { @test_class.new('t'*16, '0'*7, :encrypt) }
    obj = @test_class.new('t'*16, 'i'*16, 'encrypt')
    assert_equal(:encrypt, obj.mode)
  end

end
