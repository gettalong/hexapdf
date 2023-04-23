# -*- encoding: utf-8; frozen_string_literal: true -*-
#
#--
# This file is part of HexaPDF.
#
# HexaPDF - A Versatile PDF Creation and Manipulation Library For Ruby
# Copyright (C) 2014-2023 Thomas Leitner
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

  # The composer class can be used to create PDF documents from scratch. It uses
  # HexaPDF::Layout::Frame and HexaPDF::Layout::Box objects underneath and binds them together to
  # provide a convenient interface for working with them.
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

    # The HexaPDF::Layout::Frame for automatic box placement.
    attr_reader :frame

    # Creates a new Composer object and optionally yields it to the given block.
    #
    # skip_page_creation::
    #     If this argument is +true+ (the default), the arguments +page_size+, +page_orientation+
    #     and +margin+ are used to create a page style with the name :default and an initial page is
    #     created as well.
    #
    #     Otherwise, i.e. when this argument is +false+, no initial page or default page style is
    #     created. This has to be done manually using the #page_style and #new_page methods.
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
    #     The margin to use. See HexaPDF::Layout::Style::Quad#set for possible values.
    #
    # Example:
    #
    #   composer = HexaPDF::Composer.new            # uses the default values
    #
    #   HexaPDF::Composer.new(page_size: :Letter, margin: 72) do |composer|
    #     #...
    #   end
    #
    #   HexaPDF::Composer.new(skip_page_creation: true) do |composer|
    #     page_template = lambda {|canvas, style| style.create_frame(canvas.context, 36) }
    #     page_style(:default, template: page_template)
    #     new_page
    #     # ...
    #   end
    def initialize(skip_page_creation: false, page_size: :A4, page_orientation: :portrait,
                   margin: 36) #:yields: composer
      @document = HexaPDF::Document.new
      @page_styles = {}
      @next_page_style = :default
      unless skip_page_creation
        page_style(:default, page_size: page_size, orientation: page_orientation) do |canvas, style|
          style.frame = style.create_frame(canvas.context, margin)
        end
        new_page
      end
      yield(self) if block_given?
    end

    # Creates a new page, making it the current one.
    #
    # The page style to use for the new page can be set via the +style+ argument. If not provided,
    # the currently set page style is used.
    #
    # The used page style determines the page style that should be used for the following new pages.
    # If this information is not provided, the used page style is used again.
    #
    # Examples:
    #
    #   composer.page_style(:cover, page_size: :A4).next_style = :content
    #   composer.page_style(:content, page_size: :A4)
    #   composer.new_page(:cover)           # uses the :cover style, set next style to :content
    #   composer.new_page                   # uses the :content style, next style again :content
    def new_page(style = @next_page_style)
      page_style = @page_styles.fetch(style) do |key|
        raise ArgumentError, "Page style #{key} has not been defined"
      end
      @page = @document.pages.add(page_style.create_page(@document))
      @canvas = @page.canvas
      @frame = page_style.frame
      @next_page_style = page_style.next_style || style
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

    # :call-seq:
    #    composer.style(name)                              -> style
    #    composer.style(name, base: :base, **properties)   -> style
    #
    # Creates or updates the HexaPDF::Layout::Style object called +name+ with the given property
    # values and returns it.
    #
    # See HexaPDF::Document::Layout#style for details; this method is just a thin wrapper around
    # that method.
    #
    # Example:
    #
    #   composer.style(:base, font_size: 12, leading: 1.2)
    #   composer.style(:header, font: 'Helvetica', fill_color: "008")
    #   composer.style(:header1, base: :header, font_size: 30)
    #
    # See: HexaPDF::Layout::Style
    def style(name, base: :base, **properties)
      @document.layout.style(name, base: base, **properties)
    end

    # :call-seq:
    #    composer.page_style(name)                                 -> page_style
    #    composer.page_style(name, **attributes, &template_block)  -> page_style
    #
    # Creates and/or returns the page style +name+.
    #
    # If no attributes are given, the page style +name+ is returned. In case it does not exist,
    # +nil+ is returned.
    #
    # If one or more page style attributes are given, a new HexaPDF::Layout::PageStyle object with
    # those attribute values is created, stored under +name+ and returned. If a block is provided,
    # it is used to define the page template.
    #
    # Example:
    #
    #   composer.page_style(:default)
    #   composer.page_style(:cover, page_size: :A4) do |canvas, style|
    #     page_box = canvas.context.box
    #     canvas.fill_color("fd0") do
    #       canvas.rectangle(0, 0, page_box.width, page_box.height).
    #         fill
    #     end
    #     style.frame = style.create_frame(canvas.context, 36)
    #   end
    #
    # See: HexaPDF::Layout::PageStyle
    def page_style(name, **attributes, &block)
      if attributes.empty?
        @page_styles[name]
      else
        @page_styles[name] = HexaPDF::Layout::PageStyle.new(**attributes, &block)
      end
    end

    # Draws the given text at the current position into the current frame.
    #
    # The text will be positioned at the current position if possible. Otherwise the next best
    # position is used. If the text doesn't fit onto the current page or only partially, new pages
    # are created automatically.
    #
    # This method is of the two main methods for creating text boxes, the other being
    # #formatted_text. It uses HexaPDF::Document::Layout#text_box behind the scenes to create the
    # HexaPDF::Layout::TextBox that does the actual work.
    #
    # See HexaPDF::Document::Layout#text_box for details on the arguments.
    #
    # Examples:
    #
    #   #>pdf-composer
    #   composer.text("Test " * 15)
    #   composer.text("Now " * 7, width: 100)
    #   composer.text("Another test", font_size: 15, fill_color: "green")
    #   composer.text("Different box style", fill_color: 'white', box_style: {
    #     underlays: [->(c, b) { c.rectangle(0, 0, b.content_width, b.content_height).fill }]
    #   })
    def text(str, width: 0, height: 0, style: nil, box_style: nil, **style_properties)
      draw_box(@document.layout.text_box(str, width: width, height: height, style: style,
                                         box_style: box_style, **style_properties))
    end

    # Draws text like #text but allows parts of the text to be formatted differently.
    #
    # It uses HexaPDF::Document::Layout#formatted_text_box behind the scenes to create the
    # HexaPDF::Layout::TextBox that does the actual work. See that method for details on the
    # arguments.
    #
    # Examples:
    #
    #   #>pdf-composer
    #   composer.formatted_text(["Some string"])
    #   composer.formatted_text(["Some ", {text: "string", fill_color: 128}])
    #   composer.formatted_text(["Some ", {link: "https://example.com",
    #                                      fill_color: 'blue', text: "Example"}])
    #   composer.formatted_text(["Some ", {text: "string", style: {font_size: 20}}])
    #
    # See: #text, HexaPDF::Layout::TextBox, HexaPDF::Layout::TextFragment
    def formatted_text(data, width: 0, height: 0, style: nil, box_style: nil, **style_properties)
      draw_box(@document.layout.formatted_text_box(data, width: width, height: height, style: style,
                                                   box_style: box_style, **style_properties))
    end

    # Draws the given image at the current position.
    #
    # It uses HexaPDF::Document::Layout#image_box behind the scenes to create the
    # HexaPDF::Layout::ImageBox that does the actual work. See that method for details on the
    # arguments.
    #
    # Examples:
    #
    #   #>pdf-composer
    #   composer.image(machu_picchu, border: {width: 3})
    #   composer.image(machu_picchu, height: 30)
    #
    # See: HexaPDF::Layout::ImageBox
    def image(file, width: 0, height: 0, style: nil, **style_properties)
      draw_box(@document.layout.image_box(file, width: width, height: height,
                                          style: style, **style_properties))
    end

    # Draws the named box at the current position.
    #
    # It uses HexaPDF::Document::Layout#box behind the scenes to create the named box. See that
    # method for details on the arguments.
    #
    # Examples:
    #
    #   #>pdf-composer
    #   composer.box(:image, image: composer.document.images.add(machu_picchu))
    #
    # See: HexaPDF::Document::Layout#box
    def box(name, width: 0, height: 0, style: nil, **box_options, &block)
      draw_box(@document.layout.box(name, width: width, height: height, style: style, **box_options, &block))
    end

    # Draws any custom box that can be created using HexaPDF::Document::Layout.
    #
    # Examples:
    #
    #   #>pdf-composer
    #   composer.lorem_ipsum
    #   composer.column {|column| column.lorem_ipsum }
    def method_missing(name, *args, **kwargs, &block)
      if @document.layout.box_creation_method?(name)
        draw_box(@document.layout.send(name, *args, **kwargs, &block))
      else
        super
      end
    end

    # :nodoc:
    def respond_to_missing?(name, _private)
      @document.layout.box_creation_method?(name) || super
    end

    # Draws the given HexaPDF::Layout::Box.
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
        result = @frame.fit(box)
        if result.success?
          @frame.draw(@canvas, result)
          break
        elsif @frame.full?
          new_page
          drawn_on_page = false
        else
          draw_box, box = @frame.split(result)
          if draw_box
            @frame.draw(@canvas, result)
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

    # Creates a stamp (Form XObject) which can be used like an image multiple times on a single page
    # or on multiple pages.
    #
    # The width and the height of the stamp need to be set (frame.width/height or
    # page.box.width/height might be good choices).
    #
    # Examples:
    #
    #   #>pdf-composer
    #   stamp = composer.create_stamp(50, 50) do |canvas|
    #     canvas.fill_color("red").line_width(5).
    #       rectangle(10, 10, 30, 30).fill_stroke
    #   end
    #   composer.image(stamp, width: 20, height: 20)
    #   composer.image(stamp, width: 50)
    def create_stamp(width, height) # :yield: canvas
      stamp = @document.add({Type: :XObject, Subtype: :Form, BBox: [0, 0, width, height]})
      yield(stamp.canvas) if block_given?
      stamp
    end

  end

end
