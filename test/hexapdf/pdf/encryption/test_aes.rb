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
        [mode, data]
      end

    end
  end

  it "extends the class object with the necessary methods" do
    assert_respond_to(@test_class, :encrypt)
    assert_respond_to(@test_class, :decrypt)
  end

  it "correctly invokes encryption/decryption via klass methods" do
    assert_equal([:encrypt, '5'], @test_class.encrypt('some key'*2, 'some  iv'*2, '5'))
    assert_equal([:decrypt, '5'], @test_class.decrypt('some key'*2, 'some  iv'*2, '5'))
  end

  it "does basic validation on initialization" do
    assert_raises(HexaPDF::Error) { @test_class.new('t'*7, '0'*16, :encrypt) }
    assert_raises(HexaPDF::Error) { @test_class.new('t'*16, '0'*7, :encrypt) }
    obj = @test_class.new('t'*16, 'i'*16, 'encrypt')
    assert_equal(:encrypt, obj.mode)
  end

end
