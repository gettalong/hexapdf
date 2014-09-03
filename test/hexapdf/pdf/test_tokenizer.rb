# -*- encoding: utf-8 -*-

require 'test_helper'
require 'hexapdf/pdf/tokenizer'
require 'stringio'

class PDFTokenizerTest < Minitest::Test

  def setup
    @io = StringIO.new
    @tokenizer = HexaPDF::PDF::Tokenizer.new(@io)
  end

  def test_pos
    @io.string = "hallo du" + " "*50000 + "hallo du"
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

  def test_peek_token
    2.times do
      @io.string = "hallo du"
      assert_equal('hallo', @tokenizer.peek_token)
      assert_equal(0, @tokenizer.pos)
    end
  end

  def test_next_token
    @io.string = <<EOF
% Regular tokens
  		
true false
123 +17 -98 0
34.5 -3.62 +123.6 4. -.002 .002 0.0

% Literal string tests
(parentheses ( ) and \\(
special \\0053\\053\\53characters (*!&}^% and \\
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
EOF

    expected_tokens = [true, false,
                       123, 17, -98, 0,
                       34.5, -3.62, 123.6, 4.0, -0.002, 0.002, 0.0,
                       "parentheses ( ) and (\nspecial \0053++characters (*!&}^% and so on).\n", '',
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

end
