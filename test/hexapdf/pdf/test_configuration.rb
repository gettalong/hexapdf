# -*- encoding: utf-8 -*-

require 'test_helper'
require 'hexapdf/pdf/configuration'

describe HexaPDF::PDF::Configuration do
  before do
    @config = HexaPDF::PDF::Configuration.new
    @config['test'] = :test
  end

  it "can create a config based on the default one with certain values overwritten" do
    config = HexaPDF::PDF::Configuration.with_defaults('io.chunk_size' => 10)
    assert_equal(10, config['io.chunk_size'])
    assert_equal(:A4, config['page.default_media_box'])
  end

  it "can check the availabilty of an option" do
    assert(@config.option?('test'))
  end

  it "can return the value for an option" do
    assert_equal(:test, @config['test'])
  end

  it "can set the value for an option" do
    @config['test'] = :other
    assert_equal(:other, @config['test'])
  end

  it "can create a new config object by merging another one or a hash" do
    @config['hash'] = {'test' => :test, 'other' => :other}
    config = @config.merge('test' => :other)
    assert_equal(:other, config['test'])

    config['hash']['test'] = :other
    config = @config.merge(config)
    assert_equal(:other, config['hash']['test'])
    assert_equal(:other, config['hash']['other'])
  end

  describe "constantize" do
    it "returns a constant for an option with a string value" do
      @config['test'] = 'HexaPDF'
      assert_equal(HexaPDF, @config.constantize('test'))
    end

    it "returns a constant for an option with a constant as value" do
      @config['test'] = HexaPDF
      assert_equal(HexaPDF, @config.constantize('test'))
    end

    it "returns a constant for a nested option" do
      @config['test'] = {'test' => 'HexaPDF', 'const' => HexaPDF}
      assert_equal(HexaPDF, @config.constantize('test', 'test'))
      assert_equal(HexaPDF, @config.constantize('test', 'const'))

      @config['test'] = ['HexaPDF', HexaPDF]
      assert_equal(HexaPDF, @config.constantize('test', 0))
      assert_equal(HexaPDF, @config.constantize('test', 1))
    end

    it "returns nil for an unknown option" do
      assert_nil(@config.constantize('unknown'))
    end

    it "returns nil for an unknown constant" do
      @config['test'] = 'SomeUnknownConstant'
      assert_nil(@config.constantize('test'))
    end

    it "returns nil for an unknown constant using a nested option" do
      @config['test'] = {}
      assert_nil(@config.constantize('test', 'test'))
      assert_nil(@config.constantize('test', nil))
    end

    it "returns the result of the given block when no constant is found" do
      assert_equal(:test, @config.constantize('unk') {|name| assert_equal('unk', name); :test})
    end
  end
end
