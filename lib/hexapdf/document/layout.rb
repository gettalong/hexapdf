# -*- encoding: utf-8; frozen_string_literal: true -*-
#
#--
# This file is part of HexaPDF.
#
# HexaPDF - A Versatile PDF Creation and Manipulation Library For Ruby
# Copyright (C) 2014-2022 Thomas Leitner
#
# HexaPDF is free software: you can redistribute it and/or modify it
# under the terms of the GNU Affero General Public License version 3 as
# published by the Free Software Foundation with the addition of the
# following permission added to Section 15 as permitted in Section 7(a):
# FOR ANY PART OF THE COVERED WORK IN WHICH THE COPYRIGHT IS OWNED BY
# THOMAS LEITNER, THOMAS LEITNER DISCLAIMS THE WARRANTY OF NON
# INFRINGEMENT OF THIRD PARTY RIGHTS.
#
# HexaPDF is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
# FITNESS FOR A PARTICULAR PURPOSE. See the GNU Affero General Public
# License for more details.
#
# You should have received a copy of the GNU Affero General Public License
# along with HexaPDF. If not, see <http://www.gnu.org/licenses/>.
#
# The interactive user interfaces in modified source and object code
# versions of HexaPDF must display Appropriate Legal Notices, as required
# under Section 5 of the GNU Affero General Public License version 3.
#
# In accordance with Section 7(b) of the GNU Affero General Public
# License, a covered work must retain the producer line in every PDF that
# is created or manipulated using HexaPDF.
#
# If the GNU Affero General Public License doesn't fit your need,
# commercial licenses are available at <https://gettalong.at/hexapdf/>.
#++

require 'hexapdf/layout'

module HexaPDF
  class Document

    # This class provides methods for working with classes in the HexaPDF::Layout module.
    #
    # Often times the layout related classes are used through HexaPDF::Composer which makes it easy
    # to create documents. However, sometimes one wants to have a bit more control or do something
    # special and use the HexaPDF::Layout classes directly. This is possible but it is better to use
    # those classes through an instance of this classs because it makes it more convenient and ties
    # everything together. Incidentally, HexaPDF::Composer relies on this class for a good part of
    # its work.
    #
    #
    # == Boxes
    #
    # The main focus of the class is on providing convenience methods for creating box objects. The
    # most often used box classes like HexaPDF::Layout::TextBox or HexaPDF::Layout::ImagebBox can be
    # created through dedicated methods.
    #
    # Other, more general boxes don't have their own method but can be created through the general
    # #box method.
    #
    #
    # == Box Styles
    #
    # All box creation methods accept HexaPDF::Layout::Style objects or names for style objects
    # (defined via #style). This allows one to predefine certain styles (like first level heading,
    # second level heading, paragraph, ...) and consistently use them throughout the document
    # creation process.
    #
    # One style property, HexaPDF::Layout::Style#font, is handled specially:
    #
    # * If no font is set on a style, the font "Times" is automatically set because otherwise there
    #   would be problems with text drawing operations (font is the only style property that has no
    #   valid default value).
    #
    # * Standard style objects only allow font wrapper objects to be set via the
    #   HexaPDF::Layout::Style#font method. This class makes usage easier by allowing strings or an
    #   array [name, options_hash] to be used, like with e.g Content::Canvas#font. So to use
    #   Helvetica as font, one could just do:
    #
    #     style.font = 'Helvetica'
    #
    #   And if Helvetica in its bold variant should be used it would be:
    #
    #     style.font = ['Helvetica', variant: :bold]
    #
    class Layout

      # The mapping of style name (a Symbol) to HexaPDF::Layout::Style instance.
      attr_reader :styles

      # Creates a new Layout object for the given PDF document.
      def initialize(document)
        @document = document
        @styles = {base: HexaPDF::Layout::Style.new}
      end

      # :call-seq:
      #    layout.style(name)                              -> style
      #    layout.style(name, base: :base, **properties)   -> style
      #
      # Creates or updates the HexaPDF::Layout::Style object called +name+ with the given property
      # values and returns it.
      #
      # This method allows convenient access to the stored styles and to update them. Such styles
      # can then be used by name in the various box creation methods, e.g. #text_box or #image_box.
      #
      # If neither +base+ nor any style properties are specified, the style +name+ is just returned.
      #
      # If the style +name+ does not exist yet and the argument +base+ specifies the name of another
      # style, that style is duplicated and used as basis for the style. This also means that the
      # referenced +base+ style needs be defined first!
      #
      # The special name :base should be used for setting the base style which is used when no
      # specific style is set.
      #
      # Note that the style property 'font' is handled specially, see the class documentation for
      # details.
      #
      # Example:
      #
      #   layout.style(:base, font_size: 12, leading: 1.2)
      #   layout.style(:header, font: 'Helvetica', fill_color: "008")
      #   layout.style(:header1, base: :header, font_size: 30)
      #
      # See: HexaPDF::Layout::Style
      def style(name, base: :base, **properties)
        style = @styles[name] ||= (@styles.key?(base) ? @styles[base].dup : HexaPDF::Layout::Style.new)
        style.update(**properties) unless properties.empty?
        style
      end

      # Creates a HexaPDF::Layout::TextBox for the given text.
      #
      # This method is of the two main methods for creating text boxes, the other being
      # #formatted_text_box.
      #
      # +width+, +height+::
      #     The arguments +width+ and +height+ are used as constraints and are respected when
      #     fitting the box. The default value of 0 means that no constraints are set.
      #
      # +style+, +style_properties+::
      #     The box and the text are styled using the given +style+. This can either be a style name
      #     set via #style or anything HexaPDF::Layout::Style::create accepts. If any additional
      #     +style_properties+ are specified, the style is duplicated and the additional styles are
      #     applied.
      #
      # +box_style+::
      #     Sometimes it is necessary for the box to have a different style than the text, e.g. when
      #     using overlays. In such a case use +box_style+ for specifiying the style of the box (a
      #     style name set via #style or anything HexaPDF::Layout::Style::create accepts).
      #
      #     The +style+ together with the +style_properties+ will be used for the text style.
      #
      # Examples:
      #
      #   layout.text("Test " * 15)
      #   layout.text("Now " * 7, width: 100)
      #   layout.text("Another test", font_size: 15, fill_color: "green")
      #   layout.text("Different box style", fill_color: 'white', box_style: {
      #     underlays: [->(c, b) { c.rectangle(0, 0, b.content_width, b.content_height).fill }]
      #   })
      #
      # See: #formatted_text_box, HexaPDF::Layout::TextBox, HexaPDF::Layout::TextFragment
      def text_box(text, width: 0, height: 0, style: nil, box_style: nil, **style_properties)
        style = retrieve_style(style, style_properties)
        box_style = (box_style ? retrieve_style(box_style) : style)
        HexaPDF::Layout::TextBox.new([HexaPDF::Layout::TextFragment.create(text, style)],
                                     width: width, height: height, style: box_style)
      end

      # Creates a HexaPDF::Layout::TextBox like #text_box but allows parts of the text to be
      # formatted differently.
      #
      # The argument +data+ needs to be an array of String and/or Hash objects:
      #
      # * A String object is treated like {text: data}.
      #
      # * Hashes can contain any style properties and the following special keys:
      #
      #   text:: The text to be formatted.
      #
      #   link:: A URL that should be linked to. If no text is provided but a link, the link is used
      #          as text.
      #
      #   style:: The style to be use as base style instead of the style created from the +style+
      #           and +style_properties+ arguments. See HexaPDF::Layout::Style::create for allowed
      #           values.
      #
      #   If any style properties are set, the used style is duplicated and the additional
      #   properties applied.
      #
      # See #text_box for details on +width+, +height+, +style+, +style_properties+ and +box_style+.
      #
      # Examples:
      #
      #   layout.formatted_text_box(["Some string"])
      #   layout.formatted_text_box(["Some ", {text: "string", fill_color: 128}])
      #   layout.formatted_text_box(["Some ", {link: "https://example.com",
      #                                        fill_color: 'blue', text: "Example"}])
      #   layout.formatted_text_box(["Some ", {text: "string", style: {font_size: 20}}])
      #
      # See: #text_box, HexaPDF::Layout::TextBox, HexaPDF::Layout::TextFragment
      def formatted_text_box(data, width: 0, height: 0, style: nil, box_style: nil, **style_properties)
        style = retrieve_style(style, style_properties)
        box_style = (box_style ? retrieve_style(box_style) : style)
        data.map! do |hash|
          if hash.kind_of?(String)
            HexaPDF::Layout::TextFragment.create(hash, style)
          else
            link = hash.delete(:link)
            (hash[:overlays] ||= []) << [:link, {uri: link}] if link
            text = hash.delete(:text) || link || ""
            HexaPDF::Layout::TextFragment.create(text, retrieve_style(hash.delete(:style) || style, hash))
          end
        end
        HexaPDF::Layout::TextBox.new(data, width: width, height: height, style: box_style)
      end

      # Creates a HexaPDF::Layout::ImageBox for the given image.
      #
      # The +file+ argument can be anything that is accepted by HexaPDF::Document::Images#add or a
      # HexaPDF::Type::Form object.
      #
      # See #text_box for details on +width+, +height+, +style+ and +style_properties+.
      #
      # Examples:
      #
      #   layout.image_box(machu_picchu, border: {width: 3})
      #   layout.image_box(machu_picchu, height: 30)
      #
      # See: HexaPDF::Layout::ImageBox
      def image_box(file, width: 0, height: 0, style: nil, **style_properties)
        style = retrieve_style(style, style_properties)
        image = file.kind_of?(HexaPDF::Stream) ? file : @document.images.add(file)
        HexaPDF::Layout::ImageBox.new(image, width: width, height: height, style: style)
      end

      # :nodoc:
      LOREM_IPSUM = [
        "Lorem ipsum dolor sit amet, con\u{00AD}sectetur adipis\u{00AD}cing elit, sed " \
          "do eiusmod tempor incididunt ut labore et dolore magna aliqua.",
        "Ut enim ad minim veniam, quis nostrud exer\u{00AD}citation ullamco laboris nisi ut " \
          "aliquip ex ea commodo consequat. ",
        "Duis aute irure dolor in reprehen\u{00AD}derit in voluptate velit esse cillum dolore " \
          "eu fugiat nulla pariatur. ",
        "Excepteur sint occaecat cupidatat non proident, sunt in culpa qui officia deserunt " \
          "mollit anim id est laborum.",
      ]

      # Uses #text_box to create +count+ paragraphs of lorem ipsum text.
      #
      # The +text_box_properties+ arguments are passed as is to #text_box.
      def lorem_ipsum_box(sentences: 4, count: 1, **text_box_properties)
        text_box(([LOREM_IPSUM[0, sentences].join(" ")] * count).join("\n\n"), **text_box_properties)
      end

      private

      # Retrieves the appropriate HexaPDF::Layout::Style object based on the +style+ and +properties+
      # arguments.
      #
      # The +style+ argument specifies the style to retrieve. It can either be a registered style
      # name (see #style), a hash with style properties or +nil+. In the latter case the registered
      # style :base is used
      #
      # If the +properties+ hash is not empty, the retrieved style is duplicated and the properties
      # hash is applied to it.
      #
      # Finally, a default font is set if necessary to ensure that the style object works in all
      # cases.
      def retrieve_style(style, properties = nil)
        style = HexaPDF::Layout::Style.create(@styles[style] || style || @styles[:base])
        style = style.dup.update(**properties) unless properties.nil? || properties.empty?
        style.font('Times') unless style.font?
        unless style.font.respond_to?(:pdf_object)
          name, options = *style.font
          style.font(@document.fonts.add(name, **(options || {})))
        end
        style
      end

    end

  end
end
