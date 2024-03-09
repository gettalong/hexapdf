# -*- encoding: utf-8 -*-

require 'stringio'
require 'test_helper'
require 'hexapdf/document'

describe HexaPDF::Task::PDFA do
  before do
    @doc = HexaPDF::Document.new
  end

  it "fails if the given PDF/A level is invalid" do
    assert_raises(ArgumentError) { @doc.task(:pdfa, level: '1a') }
    assert_raises(ArgumentError) { @doc.task(:pdfa, level: '2a') }
    assert_raises(ArgumentError) { @doc.task(:pdfa, level: '3a') }
    assert_raises(ArgumentError) { @doc.task(:pdfa, level: '4e') }
    assert_raises(ArgumentError) { @doc.task(:pdfa, level: 'something') }
  end

  it "removes the standard 14 PDF font loader" do
    @doc.task(:pdfa)
    assert_raises(HexaPDF::Error) { @doc.fonts.add('Helvetia') }
  end

  it "adds the necessary XMP metadata entries before the document is written" do
    @doc.task(:pdfa, level: '3b')
    @doc.write(StringIO.new)
    assert_equal('3', @doc.metadata.property('pdfaid', 'part'))
    assert_equal('B', @doc.metadata.property('pdfaid', 'conformance'))
  end

  it "adds an RGB output intent before the document is written" do
    @doc.task(:pdfa)
    @doc.write(StringIO.new)
    oi = @doc.catalog[:OutputIntents].first
    assert_equal(:GTS_PDFA1, oi[:S])
    assert_equal('sRGB2014.icc', oi[:OutputConditionIdentifier])
    assert_equal('sRGB2014.icc', oi[:Info])
    assert_kind_of(HexaPDF::Stream, oi[:DestOutputProfile])
  end
end
