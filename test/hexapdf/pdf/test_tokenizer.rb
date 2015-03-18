# -*- encoding: utf-8 -*-

require 'test_helper'
require 'hexapdf/pdf/tokenizer'
require 'stringio'

describe HexaPDF::PDF::Tokenizer do

  def set_string(str)
    @tokenizer = HexaPDF::PDF::Tokenizer.new(StringIO.new(str.b))
  end

  it "returns the correct position on operations" do
    set_string("hallo du" + " "*50000 + "hallo du")
    @tokenizer.parse_token
    assert_equal(5, @tokenizer.pos)

    @tokenizer.skip_whitespace
    assert_equal(6, @tokenizer.pos)

    @tokenizer.next_byte
    assert_equal(7, @tokenizer.pos)

    @tokenizer.peek_byte
    assert_equal(7, @tokenizer.pos)

    @tokenizer.peek_token
    assert_equal(7, @tokenizer.pos)

    @tokenizer.parse_token
    assert_equal(8, @tokenizer.pos)

    @tokenizer.parse_token
    assert_equal(50013, @tokenizer.pos)

    @tokenizer.parse_token
    assert_equal(50016, @tokenizer.pos)

    @tokenizer.parse_token
    assert_equal(50016, @tokenizer.pos)
  end

  it "returns the next byte" do
    set_string('hallo')
    assert_equal('h', @tokenizer.next_byte)
    assert_equal('a', @tokenizer.next_byte)
  end

  it "peeks at the next byte" do
    set_string('hallo')
    assert_equal('h', @tokenizer.peek_byte)
    assert_equal('h', @tokenizer.peek_byte)
  end

  it "returns the next token but doesn't advance the position on peek_token" do
    set_string("hallo du")
    2.times do
      assert_equal('hallo', @tokenizer.peek_token)
      assert_equal(0, @tokenizer.pos)
    end
  end

  describe "parse_token" do
    it "returns all available kinds of tokens on parse_token" do
      set_string(<<-EOF.chomp.gsub(/^ {8}/, ''))
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
        token = @tokenizer.parse_token
        assert_equal(expected_token, token)
        assert_equal(Encoding::BINARY, token.encoding) if token.kind_of?(String)
      end
      assert_equal(0, expected_tokens.length)
      assert_equal(HexaPDF::PDF::Tokenizer::NO_MORE_TOKENS, @tokenizer.parse_token)
    end

    it "should return name tokens in US-ASCII/UTF-8 or binary encoding" do
      set_string("/ASomewhatLongerName")
      token = @tokenizer.parse_token
      assert_equal(:ASomewhatLongerName, token)
      assert_equal(Encoding::US_ASCII, token.encoding)

      set_string("/Hößgang")
      token = @tokenizer.parse_token
      assert_equal(:"Hößgang", token)
      assert_equal(Encoding::UTF_8, token.encoding)

      set_string('/H#c3#b6#c3#9fgang')
      token = @tokenizer.parse_token
      assert_equal(:"Hößgang", token)
      assert_equal(Encoding::UTF_8, token.encoding)

      set_string('/H#E8lp')
      token = @tokenizer.parse_token
      assert_equal("H\xE8lp".b.intern, token)
      assert_equal(Encoding::BINARY, token.encoding)
    end

    it "fails on a greater than sign that is not part of a hex string" do
      set_string(" >")
      assert_raises(HexaPDF::MalformedPDFError) { @tokenizer.parse_token }
    end

    it "fails on a missing greater than sign in a hex string" do
      set_string("<ABCD")
      assert_raises(HexaPDF::MalformedPDFError) { @tokenizer.parse_token }
    end

    it "fails on unbalanced parentheses in a literal string" do
      set_string("(href(test)")
      assert_raises(HexaPDF::MalformedPDFError) { @tokenizer.parse_token }
    end

    it "should not fail when resetting the position (due to the use of the internal StringScanner buffer)" do
      set_string("0 1 2 3 4 " * 4000)
      4000.times do
        5.times {|i| assert_equal(i, @tokenizer.parse_token)}
      end
    end
  end

  describe "next_xref_entry" do
    it "works on correct entries" do
      set_string("0000000001 00001 n \n0000000001 00032 f \n")
      assert_equal([1, 1, 'n'], @tokenizer.next_xref_entry)
      assert_equal([1, 32, 'f'], @tokenizer.next_xref_entry)
    end

    it "fails on invalidly formatted entries" do
      set_string("0000000001 00001 g \n")
      assert_raises(HexaPDF::MalformedPDFError) { @tokenizer.next_xref_entry }
    end
  end

  describe "parse_object" do
    it "works for all PDF object types, including reference, array and dictionary" do
      set_string(<<-EOF.chomp.gsub(/^ {8}/, ''))
        true false null 123 34.5 (string) <4E6F76> /Name 1 0 R 2 15 R
        [5 6 /Name] <</Name 5>>
        EOF
      assert_equal(true, @tokenizer.parse_object)
      assert_equal(false, @tokenizer.parse_object)
      assert_nil(@tokenizer.parse_object)
      assert_equal(123, @tokenizer.parse_object)
      assert_equal(34.5, @tokenizer.parse_object)
      assert_equal("string".b, @tokenizer.parse_object)
      assert_equal("Nov".b, @tokenizer.parse_object)
      assert_equal(:Name, @tokenizer.parse_object)
      assert_equal(HexaPDF::PDF::Reference.new(1, 0), @tokenizer.parse_object)
      assert_equal(HexaPDF::PDF::Reference.new(2, 15), @tokenizer.parse_object)
      assert_equal([5, 6, :Name], @tokenizer.parse_object)
      assert_equal({Name: 5}, @tokenizer.parse_object)
    end

    it "fails if the value is not a correct object" do
      set_string("<< /name ] >>")
      assert_raises(HexaPDF::MalformedPDFError) { @tokenizer.parse_object }
      set_string("other")
      assert_raises(HexaPDF::MalformedPDFError) { @tokenizer.parse_object }
      set_string("<< (string) (key) >>")
      assert_raises(HexaPDF::MalformedPDFError) { @tokenizer.parse_object }
      set_string("<< /NoValueForKey >>")
      assert_raises(HexaPDF::MalformedPDFError) { @tokenizer.parse_object }
    end
  end

end
