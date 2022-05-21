# -*- encoding: utf-8; frozen_string_literal: true -*-
#
#--
# This file is part of HexaPDF.
#
# HexaPDF - A Versatile PDF Creation and Manipulation Library For Ruby
# Copyright (C) 2014-2021 Thomas Leitner
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
  # All drawing methods accept HexaPDF::Layout::Style objects or names for style objects (defined
  # via #style). The HexaPDF::Layout::Style#font is handled specially:
  #
  # * If no font is set on a style, the font "Times" is automatically set because otherwise there
  #   would be problems with text drawing operations (font is the only style property that has no
  #   valid default value).
  #
  # * Standard style objects only allow font wrapper objects to be set via the
  #   HexaPDF::Layout::Style#font method. Composer makes usage easier by allowing strings or an
  #   array [name, options_hash] to be used, like with e.g Content::Canvas. So using Helvetica as
  #   font, one could just do this by saying
  #
  #     style.font = 'Helvetica'
  #
  #   And if Helvetica bold should be used it would be
  #
  #     style.font = ['Helvetica', variant: :bold]
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
    #   HexaPDF::Composer.new(page_size: :Letter, margin: 72) do |composer|
    #     #...
    #   end
    def initialize(page_size: :A4, page_orientation: :portrait, margin: 36) #:yields: composer
      @document = HexaPDF::Document.new
      @page_size = page_size
      @page_orientation = page_orientation
      @margin = Layout::Style::Quad.new(margin)
      @styles = {base: Layout::Style.new}

      new_page
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

    # :call-seq:
    #    composer.style(:header)                              -> style
    #    composer.style(:header, base: :base, **properties)   -> style
    #
    # Creates or updates the HexaPDF::Layout::Style object called +name+ with the given property
    # values and returns it. Such a style can then be used by name in the various box drawing
    # methods, e.g. #text or #image.
    #
    # If neither +base+ nor any style properties are specified, the style +name+ is just returned.
    #
    # If the style +name+ does not exist yet and the argument +base+ specifies the name of another
    # style, that style is duplicated and used as basis for the style.
    #
    # The special name :base should be used for setting the base style which is used when no
    # specific style is set. It is best to fully initialize the base style before creating any
    # other styles.
    #
    # Note that the style property 'font' is handled specially by Composer, see the class
    # documentation for details.
    #
    # Example:
    #
    #   composer.style(:base, font_size: 12, leading: 1.2)
    #   composer.style(:header, font: 'Helvetica', fill_color: "008")
    #   composer.style(:header1, base: :header, font_size: 30)
    #
    # See: HexaPDF::Layout::Style
    def style(name, base: :base, **properties)
      style = @styles[name] ||= (@styles.key?(base) ? @styles[base].dup : Layout::Style.new)
      style.update(**properties) unless properties.empty?
      style
    end

    # Draws the given text at the current position into the current frame.
    #
    # This method is the main method for displaying text on a PDF page. It uses a
    # HexaPDF::Layout::TextBox behind the scenes to do the actual work.
    #
    # The text will be positioned at the current position if possible. Otherwise the next best
    # position is used. If the text doesn't fit onto the current page or only partially, new pages
    # are created automatically.
    #
    # +width+, +height+::
    #     The arguments +width+ and +height+ are used as constraints and are respected when fitting
    #     the box. The default value of 0 means that no constraints are set.
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
    #     style name set via #style or anything HexaPDF::Layout::Style::create accepts). The +style+
    #     together with the +style_properties+ will be used for the text style.
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
    #
    # See HexaPDF::HexaPDF::Layout::TextBox for details.
    def text(str, width: 0, height: 0, style: nil, box_style: nil, **style_properties)
      style = retrieve_style(style, style_properties)
      box_style = (box_style ? retrieve_style(box_style) : style)
      draw_box(Layout::TextBox.new([Layout::TextFragment.create(str, style)],
                                   width: width, height: height, style: box_style))
    end

    # Draws text like #text but allows parts of the text to be formatted differently.
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
    #   style:: The style to be use as basis instead of the style created from the +style+ and
    #           +style_properties+ arguments. See HexaPDF::Layout::Style::create for allowed values.
    #
    #   If any style properties are set, the used style is copied and the additional properties
    #   applied.
    #
    # See #text for details on +width+, +height+, +style+, +style_properties+ and +box_style+.
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
      style = retrieve_style(style, style_properties)
      box_style = (box_style ? retrieve_style(box_style) : style)
      data.map! do |hash|
        if hash.kind_of?(String)
          Layout::TextFragment.create(hash, style)
        else
          link = hash.delete(:link)
          (hash[:overlays] ||= []) << [:link, {uri: link}] if link
          text = hash.delete(:text) || link || ""
          Layout::TextFragment.create(text, retrieve_style(hash.delete(:style) || style, hash))
        end
      end
      draw_box(Layout::TextBox.new(data, width: width, height: height, style: box_style))
    end

    # Draws the given image at the current position.
    #
    # The +file+ argument can be anything that is accepted by HexaPDF::Document::Images#add or a
    # HexaPDF::Type::Form object.
    #
    # See #text for details on +width+, +height+, +style+ and +style_properties+.
    #
    # Examples:
    #
    #   #>pdf-composer
    #   composer.image(machu_picchu, border: {width: 3})
    #   composer.image(machu_picchu, height: 30)
    def image(file, width: 0, height: 0, style: nil, **style_properties)
      style = retrieve_style(style, style_properties)
      image = file.kind_of?(HexaPDF::Stream) ? file : document.images.add(file)
      draw_box(Layout::ImageBox.new(image, width: width, height: height, style: style))
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

    private

    # Creates the frame into which boxes are layed out when a new page is created.
    def create_frame
      media_box = @page.box
      @frame = Layout::Frame.new(media_box.left + @margin.left,
                                 media_box.bottom + @margin.bottom,
                                 media_box.width - @margin.left - @margin.right,
                                 media_box.height - @margin.bottom - @margin.top)
    end

    # Retrieves the appropriate HexaPDF::Layout::Style object based on the +style+ and +properties+
    # arguments.
    #
    # The +style+ argument specifies the style to retrieve. It can either be a registered style name
    # (see #style), a hash with style properties or +nil+. In the latter case the registered style
    # :base is used
    #
    # If the +properties+ hash is not empty, the retrieved style is duplicated and the properties
    # hash is applied to it.
    #
    # Finally, a default font is set if necessary to ensure that the style object works in all
    # cases.
    def retrieve_style(style, properties = nil)
      style = Layout::Style.create(@styles[style] || style || @styles[:base])
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
