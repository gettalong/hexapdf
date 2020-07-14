# -*- encoding: utf-8; frozen_string_literal: true -*-
#
#--
# This file is part of HexaPDF.
#
# HexaPDF - A Versatile PDF Creation and Manipulation Library For Ruby
# Copyright (C) 2014-2020 Thomas Leitner
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

require 'hexapdf/document'
require 'hexapdf/layout'

module HexaPDF

  # The composer class can be used to create PDF documents from scratch. It uses Frame and Box
  # objects underneath.
  #
  # == Usage
  #
  # First, a new Composer objects needs to be created, either using ::new or the utility method
  # ::create.
  #
  # On creation a HexaPDF::Document object is created as well the first page and an accompanying
  # HexaPDF::Layout::Frame object. The frame is used by the various methods for general document
  # layout tasks, like positioning of text, images, and so on. By default, it covers the whole page
  # except the margin area. How the frame gets created can be customized by overriding the
  # #create_frame method.
  #
  # Once the Composer object is created, its methods can be used to draw text, images, ... on the
  # page. Behind the scenes HexaPDF::Layout::Box (and subclass) objects are created and drawn on the
  # page via the frame.
  #
  # The base style that is used by all these boxes can be defined using the #base_style method which
  # returns a HexaPDF::Layout::Style object. The only style property that is set by default is the
  # font (Times) because otherwise there would be problems with text drawing operations (font is the
  # only style property that has no valid default value).
  #
  # If the frame of a page is full and a box doesn't fit anymore, a new page is automatically
  # created. The box is either split into two boxes where one fits on the first page and the other
  # on the new page, or it is drawn completely on the new page. A new page can also be created by
  # calling the #new_page method.
  #
  # The #x and #y methods provide the point where the next box would be drawn if it fits the
  # available space. This information can be used, for example, for custom drawing operations
  # through #canvas which provides direct access to the HexaPDF::Content::Canvas object of the
  # current page.
  #
  # When using #canvas and modifying the graphics state, care has to be taken to avoid problems with
  # later box drawing operations since the graphics state cannot completely be reset (e.g.
  # transformations of the canvas cannot always be undone). So it is best to save the graphics state
  # before and restore it afterwards.
  #
  # == Example
  #
  #   HexaPDF::Composer.create('output.pdf', margin: 36) do |pdf|
  #     pdf.base_style.font_size(20).align(:center)
  #     pdf.text("Hello World", valign: :center)
  #   end
  class Composer

    # Creates a new PDF document and writes it to +output+. The +options+ are passed to ::new.
    #
    # Example:
    #
    #   HexaPDF::Composer.create('output.pdf', margin: 36) do |pdf|
    #     ...
    #   end
    def self.create(output, **options, &block)
      new(**options, &block).write(output)
    end

    # The PDF document that is created.
    attr_reader :document

    # The current page (a HexaPDF::Type::Page object).
    attr_reader :page

    # The Content::Canvas of the current page. Can be used to perform arbitrary drawing operations.
    attr_reader :canvas

    # The Layout::Frame for automatic box placement.
    attr_reader :frame

    # The base style which is used when no explicit style is provided to methods (e.g. to #text).
    attr_reader :base_style

    # Creates a new Composer object and optionally yields it to the given block.
    #
    # page_size::
    #     Can be any valid predefined page size (see Type::Page::PAPER_SIZE) or an array [llx, lly,
    #     urx, ury] specifying a custom page size.
    #
    # page_orientation::
    #     Specifies the orientation of the page, either +:portrait+ or +:landscape+. Only used if
    #     +page_size+ is one of the predefined page sizes.
    #
    # margin::
    #     The margin to use. See Layout::Style::Quad#set for possible values.
    def initialize(page_size: :A4, page_orientation: :portrait, margin: 36) #:yields: composer
      @document = HexaPDF::Document.new
      @page_size = page_size
      @page_orientation = page_orientation
      @margin = Layout::Style::Quad.new(margin)

      new_page
      @base_style = Layout::Style.new(font: 'Times')
      yield(self) if block_given?
    end

    # Creates a new page, making it the current one.
    #
    # If any of +page_size+, +page_orientation+ or +margin+ are set, they will be used instead of
    # the default values and will become the default values.
    #
    # Examples:
    #
    #   composer.new_page  # uses the default values
    #   composer.new_page(page_size: :A5, margin: [72, 36])
    def new_page(page_size: nil, page_orientation: nil, margin: nil)
      @page_size = page_size if page_size
      @page_orientation = page_orientation if page_orientation
      @margin = Layout::Style::Quad.new(margin) if margin

      @page = @document.pages.add(@page_size, orientation: @page_orientation)
      @canvas = @page.canvas
      create_frame
    end

    # The x-position of the cursor inside the current frame.
    def x
      @frame.x
    end

    # The y-position of the cursor inside the current frame.
    def y
      @frame.y
    end

    # Writes the PDF document to the given output.
    #
    # See Document#write for details.
    def write(output, optimize: true, **options)
      @document.write(output, optimize: optimize, **options)
    end

    # Draws the given text at the current position into the current frame.
    #
    # This method is the main method for displaying text on a PDF page. It uses a Layout::TextBox
    # behind the scenes to do the actual work.
    #
    # The text will be positioned at the current position if possible. Otherwise the next best
    # position is used. If the text doesn't fit onto the current page or only partially, new pages
    # are created automatically.
    #
    # The arguments +width+ and +height+ are used as constraints and are respected when fitting the
    # box.
    #
    # The text is styled using the given +style+ object (see Layout::Style) or, if no style object
    # is specified, the base style (see #base_style). If any additional style +options+ are
    # specified, the used style is copied and the additional styles are applied.
    #
    # See HexaPDF::Layout::TextBox for details.
    def text(str, width: 0, height: 0, style: nil, **options)
      style = update_style(style, options)
      draw_box(Layout::TextBox.new([Layout::TextFragment.create(str, style)],
                                   width: width, height: height, style: style))
    end

    # Draws text like #text but where parts of it can be formatted differently.
    #
    # The argument +data+ needs to be an array of String or Hash objects:
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
    #   style:: A Layout::Style object to use as basis instead of the style created from the +style+
    #           and +options+ arguments.
    #
    #   If any style properties are set, the used style is copied and the additional properties
    #   applied.
    #
    # Examples:
    #
    #   composer.formatted_text(["Some string"])   # The same as #text
    #   composer.formatted_text(["Some ", {text: "string", fill_color: 128}]
    #   composer.formatted_text(["Some ", {link: "https://example.com", text: "Example"}])
    #   composer.formatted_text(["Some ", {text: "string", style: my_style}])
    def formatted_text(data, width: 0, height: 0, style: nil, **options)
      style = update_style(style, options)
      data.map! do |hash|
        if hash.kind_of?(String)
          Layout::TextFragment.create(hash, style)
        else
          link = hash.delete(:link)
          text = hash.delete(:text) || link || ""
          used_style = update_style(hash.delete(:style), options) || style
          if link || !hash.empty?
            used_style = used_style.dup
            hash.each {|key, value| used_style.send(key, value) }
            used_style.overlays.add(:link, uri: link) if link
          end
          Layout::TextFragment.create(text, used_style)
        end
      end
      draw_box(Layout::TextBox.new(data, width: width, height: height, style: style))
    end

    # Draws the given image file at the current position.
    #
    # See #text for details on +width+, +height+, +style+ and +options+.
    def image(file, width: 0, height: 0, style: nil, **options)
      style = update_style(style, options)
      image = document.images.add(file)
      draw_box(Layout::ImageBox.new(image, width: width, height: height, style: style))
    end

    # Draws the given Layout::Box.
    #
    # The box is drawn into the current frame if possible. If it doesn't fit, the box is split. If
    # it still doesn't fit, a new region of the frame is determined and then the process starts
    # again.
    #
    # If none or only some parts of the box fit into the current frame, one or more new pages are
    # created for the rest of the box.
    def draw_box(box)
      drawn_on_page = true
      while true
        if @frame.fit(box)
          @frame.draw(@canvas, box)
          break
        elsif @frame.full?
          new_page
          drawn_on_page = false
        else
          draw_box, box = @frame.split(box)
          if draw_box
            @frame.draw(@canvas, draw_box)
            drawn_on_page = true
          elsif !@frame.find_next_region
            unless drawn_on_page
              raise HexaPDF::Error, "Box doesn't fit on empty page"
            end
            new_page
            drawn_on_page = false
          end
        end
      end
    end

    private

    # Creates the frame into which boxes are layed out when a new page is created.
    def create_frame
      media_box = @page.box
      @frame = Layout::Frame.new(media_box.left + @margin.left,
                                 media_box.bottom + @margin.bottom,
                                 media_box.width - @margin.left - @margin.right,
                                 media_box.height - @margin.bottom - @margin.top)
    end

    # Updates the Layout::Style object +style+ if one is provided, or the base style, with the style
    # options to make it work in all cases.
    def update_style(style, options = {})
      style ||= base_style
      style = style.dup.update(**options) unless options.empty?
      style.font(base_style.font) unless style.font?
      style.font(@document.fonts.add(style.font)) unless style.font.respond_to?(:pdf_object)
      style
    end

  end

end
