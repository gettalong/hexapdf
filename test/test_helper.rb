# -*- encoding: utf-8 -*-

require 'simplecov'
SimpleCov.start do
  add_filter '/test/'
end

gem 'minitest'
require 'minitest/autorun'
require 'fiber'
require 'zlib'

module TestHelper

  def feeder(string, len = string.length)
    Fiber.new do
      while string.length > 0
        Fiber.yield string.slice!(0, len).force_encoding('BINARY')
      end
    end
  end

  def collector(source)
    str = ''.force_encoding('BINARY')
    while source.alive? && data = source.resume
      str << data
    end
    str
  end

end


module StandardFilterTests

  include TestHelper

  TEST_BIG_STR = ''.force_encoding('BINARY')
  TEST_BIG_STR << [rand(2**32)].pack('N') while TEST_BIG_STR.length < 2**16
  TEST_BIG_STR.freeze

  def test_decodes_correctly
    @all_test_cases.each_with_index do |(result, str), index|
      assert_equal(result, collector(@obj.decoder(feeder(str.dup))), "testcase #{index}")
    end
  end

  def test_encodes_correctly
    @all_test_cases.each_with_index do |(str, result), index|
      assert_equal(result, collector(@obj.encoder(feeder(str.dup))), "testcase #{index}")
    end
  end

  def test_works_with_big_data
    assert_equal(TEST_BIG_STR, collector(@obj.decoder(@obj.encoder(feeder(TEST_BIG_STR.dup)))))
  end

  def test_decoder_returns_strings_in_binary_encoding
    assert_encodings(@obj.decoder(@obj.encoder(feeder('some test data', 1))), "decoder")
  end

  def test_encoder_returns_strings_in_binary_encoding
    assert_encodings(@obj.encoder(feeder('some test data', 1)), "encoder")
  end

  def assert_encodings(source, type)
    while source.alive? && data = source.resume
      assert_equal(Encoding::BINARY, data.encoding, "encoding problem in #{type}")
    end
  end

  def test_decoder_works_with_single_byte_input
    assert_equal(@decoded, collector(@obj.decoder(feeder(@encoded.dup, 1))))
  end

  def test_encoder_works_with_single_byte_input
    assert_equal(@encoded, collector(@obj.encoder(feeder(@decoded.dup, 1))))
  end

end


module CommonARC4EncryptionTests

  def setup
    super
    @encrypted = ['BBF316E8D940AF0AD3', '1021BF0420', '45A01F645FC35B383552544B9BF5'].
      map {|c| [c].pack('H*')}
    @plain = ['Plaintext', 'pedia', 'Attack at dawn'].each {|s| s.force_encoding('BINARY')}
    @keys = ['Key', 'Wiki', 'Secret']
  end

  def test_processes_the_test_vectors_from_the_RC4_wikipeda_page
    @keys.each_with_index do |key, i|
      assert_equal(@encrypted[i], @algorithm_klass.new(key).process(@plain[i]))
    end
  end

  def test_can_accept_one_big_chunk_or_multiple_smaller_ones
    big = @algorithm_klass.new('key')
    small = @algorithm_klass.new('key')
    assert_equal(big.process('some big data chunk'),
                 small.process('some') << small.process(' big') << small.process(' data chunk'))
  end

end


module CommonAESEncryptionTests

  TEST_VECTOR_FILES = Dir[File.join(__dir__, 'data', 'aes-test-vectors', '*')]

  def test_processes_the_AES_test_vectors
    TEST_VECTOR_FILES.each do |filename|
      name, size, mode = File.basename(filename, '.data.gz').split('-')
      size = size.to_i / 8
      data = Zlib::GzipReader.open(filename) {|io| io.read}.force_encoding(Encoding::BINARY)
      data.scan(/(.{#{size}})(.{16})(.{16})(.{16})/m).each_with_index do |(key, iv, plain, cipher), index|
        aes = @algorithm_klass.new(key, iv, mode.intern)
        assert_equal(cipher, aes.process(plain), "name: #{name}, size: #{size*8}, mode: #{mode}, index: #{index}")
      end
    end
  end

  def test_can_accept_one_big_chunk_or_multiple_smaller_ones
    big = @algorithm_klass.new('t'*16, '0'*16, :encrypt)
    small = @algorithm_klass.new('t'*16, '0'*16, :encrypt)
    assert_equal(big.process('some'*16),
                 small.process('some'*8) << small.process('some'*4) << small.process('some'*4))
  end

  def test_raises_error_on_invalid_key_length
    assert_raises(HexaPDF::Error) { @algorithm_klass.new('t'*15, '0'*16, :encrypt) }
  end

  def test_raises_error_on_invalid_iv_length
    assert_raises(HexaPDF::Error) { @algorithm_klass.new('t'*16, '0'*15, :encrypt) }
  end

end
