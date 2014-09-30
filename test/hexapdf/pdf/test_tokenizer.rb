# -*- encoding: utf-8 -*-

require 'test_helper'
require 'hexapdf/pdf/tokenizer'
require 'stringio'

class PDFTokenizerTest < Minitest::Test

  def set_string(str)
    @tokenizer = HexaPDF::PDF::Tokenizer.new(StringIO.new(str))
  end

  def test_pos
    set_string("hallo du" + " "*50000 + "hallo du")
    @tokenizer.next_token
    assert_equal(5, @tokenizer.pos)

    @tokenizer.next_token
    assert_equal(8, @tokenizer.pos)

    @tokenizer.next_token
    assert_equal(50013, @tokenizer.pos)

    @tokenizer.next_token
    assert_equal(50016, @tokenizer.pos)

    @tokenizer.next_token
    assert_equal(50016, @tokenizer.pos)
  end

  def test_next_byte
    set_string('hallo')
    assert_equal('h', @tokenizer.next_byte)
    assert_equal('a', @tokenizer.next_byte)
  end

  def test_peek_token
    set_string("hallo du")
    2.times do
      assert_equal('hallo', @tokenizer.peek_token)
      assert_equal(0, @tokenizer.pos)
    end
  end

  def test_next_token
    set_string(<<EOF.chomp)
% Regular tokens
  		
true false
123 +17 -98 0 0059
34.5 -3.62 +123.6 4. -.002 .002 0.0

% Literal string tests
(parenthese\\s ( ) and \\(\r
special \\0053\\053\\53characters\r (*!&}^% and \\
so on).\\n)
()

% Hex strings
<4E6F762073 686D6F7A20	6B612070
6F702E>
< 901FA3 ><901fA>

% Names
/Name1
/ASomewhatLongerName
/A;Name_With-Various***Characters?
/1.2/$$
/@pattern
/.notdef
/lime#20Green
/paired#28#29parentheses
/The_Key_of_F#23_Minor
/A#42
/

% Object references
1 0 R
2 15 R

% Arrays
[ 5 6 /Name ]
[5 6 /Name]

% Dictionaries
<</Name 5>>

% Test
EOF

    expected_tokens = [true, false,
                       123, 17, -98, 0, 59,
                       34.5, -3.62, 123.6, 4.0, -0.002, 0.002, 0.0,
                       "parentheses ( ) and (\nspecial \0053++characters\n (*!&}^% and so on).\n", '',
                       "Nov shmoz ka pop.", "\x90\x1F\xA3", "\x90\x1F\xA0",
                       :Name1, :ASomewhatLongerName, :"A;Name_With-Various***Characters?",
                       :"1.2", :"$$", :"@pattern", :".notdef", :"lime Green", :"paired()parentheses",
                       :"The_Key_of_F#_Minor", :"AB", :"",
                       HexaPDF::PDF::Reference.new(1, 0),
                       HexaPDF::PDF::Reference.new(2, 15),
                       '[', 5, 6, :Name, ']', '[', 5, 6, :Name, ']',
                       '<<', :Name, 5, '>>',
                      ].each {|t| t.force_encoding('BINARY') if t.respond_to?(:force_encoding)}
    while expected_tokens.length > 0
      expected_token = expected_tokens.shift
      token = @tokenizer.next_token
      assert_equal(expected_token, token)
      assert_equal(Encoding::BINARY, token.encoding) if token.kind_of?(String)
    end
    assert_equal(0, expected_tokens.length)
    assert_equal(HexaPDF::PDF::Tokenizer::NO_MORE_TOKENS, @tokenizer.next_token)
  end

  def test_position_reset_bug
    set_string("0 1 2 3 4 " * 4000)
    4000.times do
      5.times {|i| assert_equal(i, @tokenizer.next_token)}
    end
  end

  def test_invalid_token
    strings = [" >", "(href", "<ABAB"]
    strings.each do |str|
      set_string(str)
      assert_raises(HexaPDF::MalformedPDFError) { @tokenizer.next_token }
    end
  end

  def test_next_xref_entry
    set_string("0000000001 00001 n \n0000000001 00001 g \n")
    assert_equal([1, 1, 'n'], @tokenizer.next_xref_entry)
    assert_raises(HexaPDF::MalformedPDFError) { @tokenizer.next_xref_entry }
  end

end
