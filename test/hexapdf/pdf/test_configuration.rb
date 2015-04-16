# -*- encoding: utf-8 -*-

require 'test_helper'
require 'hexapdf/pdf/configuration'

describe HexaPDF::PDF::Configuration do

  before do
    @default = HexaPDF::PDF::Configuration.default
  end

  it "can create a config based on the default one with certain values overwritten" do
    config = HexaPDF::PDF::Configuration.with_defaults('encryption.aes' => 'test')
    assert_equal('test', config['encryption.aes'])
    assert_equal('HexaPDF::PDF::Encryption::FastARC4', config['encryption.arc4'])
  end

  it "can check the availabilty of an option" do
    assert(@default.option?('encryption.aes'))
  end

  it "can return the value for an option" do
    assert_equal('HexaPDF::PDF::Encryption::FastARC4', @default['encryption.arc4'])
  end

  it "can set the value for an option" do
    @default['encryption.arc4'] = 'test'
    assert_equal('test', @default['encryption.arc4'])
  end

  it "can create a new config object by merging another one or a hash" do
    config = @default.merge('encryption.aes' => 'test')
    assert_equal('test', config['encryption.aes'])

    config['filter.map'][:FlateDecode] = 'test'
    config = @default.merge(config)
    assert_equal('test', config['filter.map'][:FlateDecode])
    assert_equal('HexaPDF::PDF::Filter::FlateDecode', config['filter.map'][:Fl])
  end

end
