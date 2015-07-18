# -*- encoding: utf-8 -*-

require 'stringio'
require 'hexapdf/pdf/tokenizer'

module HexaPDF
  module PDF
    module Content

      # This class knows how to correctly parse a content stream.
      #
      # == Overview
      #
      # A content stream is mostly just a stream of PDF objects. However, there is one exception:
      # inline images.
      #
      # Since inline images don't follow the normal PDF object parsing rules, they need to be
      # handled specially and this is the reason for this class. Therefore only the BI operator is
      # ever called for inline images because the ID and EI operators are handled by the parser.
      #
      # To parse some contents the #parse method needs to be called with the contents to be parsed
      # and a Processor object which is used for processing the parsed operators.
      class Parser

        # Creates a new Parser object and calls #parse.
        def self.parse(contents, processor)
          new.parse(contents, processor)
        end

        # Parses the contents and calls the processor object for each parsed operator.
        def parse(contents, processor)
          tokenizer = Tokenizer.new(StringIO.new(contents))
          params = []
          while (obj = tokenizer.next_object(allow_keyword: true)) != Tokenizer::NO_MORE_TOKENS
            if obj.kind_of?(Tokenizer::Token)
              if obj == 'BI'.freeze
                params = parse_inline_image(tokenizer)
              end
              processor.process(obj.to_sym, params)
              params.clear
            else
              params << obj
            end
          end
        end

        private

        # Parses the inline image at the current position.
        def parse_inline_image(tokenizer)
          # BI has already been read, so read the image dictionary
          dict = {}
          while (key = tokenizer.next_object(allow_keyword: true))
            if key == 'ID'.freeze
              break
            elsif key == Tokenizer::NO_MORE_TOKENS
              raise HexaPDF::Error, "EOS while trying to read dictionary key for inline image"
            elsif !key.kind_of?(Symbol)
              raise HexaPDF::Error, "Inline image dictionary keys must be PDF name objects"
            end
            value = tokenizer.next_object
            if value == Tokenizer::NO_MORE_TOKENS
              raise HexaPDF::Error, "EOS while trying to read dictionary value for inline image"
            end
            dict[key] = value
          end

          # one whitespace character after ID
          tokenizer.next_byte

          # find the EI operator
          data = tokenizer.scan_until(/(?=EI[#{Tokenizer::WHITESPACE}])/o)
          if data.nil?
            raise HexaPDF::Error, "End inline image marker EI not found"
          end
          tokenizer.pos += 3
          [dict, data]
        end

      end

    end
  end
end
