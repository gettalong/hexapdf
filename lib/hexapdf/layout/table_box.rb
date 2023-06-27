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

require 'hexapdf/layout/box'
require 'hexapdf/layout/frame'

module HexaPDF
  module Layout

    # A TableBox allows placing boxes in a table.
    #
    # A table box instance can be fit into a rectangular area. The widths of the columns is
    # determined by the #column_widths definition. This means that there is no auto-sizing
    # supported.
    #
    # If some rows don't fit into the provided area, the table is split. The style of the original
    # table is also applied to the split box.
    #
    # Each table cell is a Box instance and can have an associated style, e.g. for creating borders
    # around the cell contents. It is also possible to create cells that span more than one row or
    # column.
    #
    # == Examples
    #
    # Let's start with a basic table:
    #
    #  #>pdf-composer
    #  cells = [[layout.text('A'), layout.text('B')],
    #           [layout.text('C'), layout.text('D')]]
    #  composer.box(:table, cells: cells)
    #
    # The style of the cells can be customized, e.g. to draw borders (note that each cell has a
    # *separate* border):
    #
    #  #>pdf-composer
    #  cells = [[layout.text('A'), layout.text('B')],
    #           [layout.text('C'), layout.text('D')]]
    #  table = layout.table(cells: cells)
    #  table.cells.each_row {|row| row.each {|cell| cell.style.border.width.set(1) } }
    #  composer.draw_box(table)
    #
    # If the table doesn't fit completely, it is automatically split (in this case, the last row
    # gets moved to the second column):
    #
    #  #>pdf-composer
    #  cells = [[layout.text('A'), layout.text('B')],
    #           [layout.text('C'), layout.text('D')],
    #           [layout.text('E'), layout.text('F')]]
    #  composer.column(height: 35) {|col| col.table(cells: cells) }
    #
    # It is also possible to use row and column spans:
    #
    #  #>pdf-composer
    #  cells = [[{content: layout.text('A'), col_span: 2}, {content: layout.text('B'), row_span: 2}],
    #           [{content: layout.text('C'), col_span: 2, row_span: 2}],
    #           [layout.text('D')]]
    #  table = layout.table(cells: cells)
    #  table.cells.each_row {|row| row.each {|cell| cell.style.border.width.set(1) } }
    #  composer.draw_box(table)
    #
    # Each table can have header rows and footer rows which are shown for all split parts:
    #
    #  #>pdf-composer
    #  header = lambda {|tb| [[{content: layout.text('Header', align: :center), col_span: 2}]] }
    #  footer = lambda {|tb| [[layout.text('F left'), layout.text('F right', align: :right)]] }
    #  cells = [[layout.text('A'), layout.text('B')],
    #           [layout.text('C'), layout.text('D')],
    #           [layout.text('E'), layout.text('F')]]
    #  composer.column(height: 60) {|col| col.table(cells: cells, header: header, footer: footer) }
    class TableBox < Box

      # Represents a single cell of the table.
      #
      # A cell is a container box that fits and draws its children with a BoxFitter. Its dimensions
      # (width and height) are not determined by its children but by the table layout algorithm.
      # Furthermore, its style can be used for drawing e.g. a cell border.
      #
      # Cell borders work similar to the separated borders model of CSS, i.e. each cell has its own
      # borders that do not overlap.
      class Cell < Box

        # The x-coordinate of the cell's top-left corner.
        #
        # The coordinate is relative to the table's content rectangle, with positive x-axis going to
        # the right and positive y-axis going to the bottom.
        #
        # This value is set by the parent Cells object during fitting and may therefore only be
        # relied on afterwards.
        attr_accessor :left

        # The y-coordinate of the cell's top-left corner.
        #
        # The coordinate is relative to the table's content rectangle, with positive x-axis going to
        # the right and positive y-axis going to the bottom.
        #
        # This value is set by the parent Cells object during fitting and may therefore only be
        # relied on afterwards.
        attr_accessor :top

        # The preferred width of the cell, determined during #fit.
        attr_reader :preferred_width

        # The preferred height of the cell, determined during #fit.
        attr_reader :preferred_height

        # The 0-based row number of the cell.
        attr_reader :row

        # The 0-based column number of the cell.
        attr_reader :column

        # The number of rows this cell spans.
        attr_reader :row_span

        # The number of columns this cell spans.
        attr_reader :col_span

        # The boxes to layout inside this cell.
        #
        # This may either be a single Box instance or an array of Box instances.
        attr_reader :children

        # Creates a new Cell instance.
        def initialize(row:, column:, children: [], row_span: nil, col_span: nil, **kwargs)
          super(**kwargs, width: 0, height: 0)
          @children = children
          @row = row
          @column = column
          @row_span = row_span || 1
          @col_span = col_span || 1
        end

        # Updates the height of the box to the given value.
        #
        # The +height+ has to be greater than or equal to the fitted height.
        def update_height(height)
          if @height == 0
            raise HexaPDF::Error, "Need to invoke #fit first"
          elsif height < @height
            raise HexaPDF::Error, "Given height needs to be at least as big as fitted height"
          end
          @height = height
        end

        # Fits the children of the table cell into the given rectangular area.
        def fit(available_width, available_height, _frame)
          @width = available_width
          width = available_width - reserved_width
          height = available_height - reserved_height
          frame = Frame.new(0, 0, width, height)
          if children.kind_of?(Box)
            fit_result = frame.fit(children)
            @preferred_width = fit_result.x + fit_result.box.width + reserved_width
            @height = @preferred_height = fit_result.box.height + reserved_height
            @fit_results = [fit_result]
            @fit_successful = fit_result.success?
          else
            box_fitter = BoxFitter.new([frame])
            children.each {|box| box_fitter.fit(box) }
            max_x_result = box_fitter.fit_results.max_by {|result| result.x + result.box.width }
            @preferred_width = max_x_result.x + max_x_result.box.width + reserved_width
            @height = @preferred_height = box_fitter.content_heights[0] + reserved_height
            @fit_results = box_fitter.fit_results
            @fit_successful = box_fitter.fit_successful?
          end
        end

        # :nodoc:
        def inspect
          "<Cell (#{row},#{column}) #{row_span}x#{col_span} #{Array(children).map(&:class)}>"
        end

        private

        # Draws the content of the cell.
        def draw_content(canvas, x, y)
          # available_width is always equal to content_width but we need to adjust for the
          # difference in the y direction between fitting and drawing
          y -= (@fit_results[0].available_height - content_height)
          @fit_results.each do |fit_result|
            fit_result.x += x
            fit_result.y += y
            fit_result.draw(canvas)
          end
        end

      end

      # Represents the cells of a TableBox.
      #
      # This class is a simple wrapper around an array of arrays and provides some utility methods
      # for managing the cells.
      #
      # == Table data transformation into correct form
      #
      # One of the main purposes of this class is to transform the cell data provided on
      # initialization into the representation a TableBox instance can work with.
      #
      # The +data+ argument for ::new is an array of arrays representing the rows of the table. Each
      # row array may contain one of the following items:
      #
      # * A single Box instance defining the content of the cell.
      # * An array of Box instances defining the content of the cell.
      # * A hash with the keys +:row_span+ (for defining the row span), +:col_span+ (for defining
      #   the column span) and +:content+ (for defining the content, again a single Box or an array
      #   of Box instances).
      #
      # Here is an example of the input data:
      #
      #  data = [[box1, {col_span: 2, content: box2}, box3],
      #          [box4, box5, {col_span: 2, row_span: 2, content: [box6.1, box6.2]}],
      #          [box7, box8]]
      #
      # And this is what the table will look like:
      #
      #  | box1 | box2         | box 3 |
      #  | box4 | box5 | box6.1 box6.2 |
      #  | box7 | box8 |               |
      class Cells

        # Creates a new Cells instance with the given +data+ which cannot be changed afterwards.
        #
        # See the class documentation for details on the +data+ argument.
        def initialize(data)
          @cells = []
          @number_of_columns = 0
          assign_data(data)
        end

        # Returns the cell (a Cell instance) in the given row and column.
        #
        # Note that the same cell instance may be returned for different (row, column) arguments if
        # the cell spans more than one row and/or column.
        def [](row, column)
          @cells[row]&.[](column)
        end

        # Returns the number of rows.
        def number_of_rows
          @cells.size
        end

        # Returns the number of columns.
        def number_of_columns
          @number_of_columns
        end

        # Iterates over each row.
        def each_row(&block)
          @cells.each(&block)
        end

        # Fits all rows starting from +start_row+ into an area with the given +available_height+,
        # using the column information in +column_info+. Returns the used height as well as the row
        # index of the last row that fit (which may be -1 if no row fits).
        #
        # The +column_info+ argument needs to be an array of arrays of the form [x_pos, width]
        # containing the horizontal positions and widths of each column.
        #
        # The fitting of a cell is done through the Cell#fit method which stores the result in the
        # cell itself. Furthermore, Cell#left and Cell#top are also assigned correctly.
        def fit_rows(start_row, available_height, column_info)
          height = available_height
          last_fitted_row_index = -1
          @cells[start_row..-1].each.with_index(start_row) do |columns, row_index|
            row_fit = true
            row_height = 0
            columns.each_with_index do |cell, col_index|
              next if cell.row != row_index || cell.column != col_index
              available_cell_width = if cell.col_span > 1
                                       column_info[cell.column, cell.col_span].map(&:last).sum
                                     else
                                       column_info[cell.column].last
                                     end
              unless cell.fit(available_cell_width, available_height, nil)
                row_fit = false
                break
              end
              cell.left = column_info[cell.column].first
              cell.top = height - available_height
              row_height = cell.preferred_height if row_height < cell.preferred_height
            end

            if row_fit
              seen = {}
              columns.each do |cell|
                next if seen[cell]
                cell.update_height(cell.row == row_index ? row_height : cell.height + row_height)
                seen[cell] = true
              end

              last_fitted_row_index = row_index
              available_height -= row_height
            else
              last_fitted_row_index = columns.min_by(&:row).row - 1 if height != available_height
              break
            end
          end
          [height - available_height, last_fitted_row_index]
        end

        # Draws the rows from +start_row+ to +end_row+ on the given +canvas+, with the top-left
        # corner of the resulting table being at (+x+, +y+).
        def draw_rows(start_row, end_row, canvas, x, y)
          @cells[start_row..end_row].each.with_index(start_row) do |columns, row_index|
            columns.each_with_index do |cell, col_index|
              next if cell.row != row_index || cell.column != col_index
              cell.draw(canvas, x + cell.left, y - cell.top - cell.height)
            end
          end
        end

        private

        # Assigns the +data+ to the individual cells, taking row and column spans into account.
        #
        # This transforms the data into an array of row arrays with the same number of columns so
        # that referencing a cell by (row, column) works correctly.
        def assign_data(data)
          data.each_with_index do |cols, row_index|
            # Only add new row array if it hasn't been added due to row spans before
            @cells << [] unless @cells[row_index]
            row = @cells[row_index]
            col_index = 0

            cols.each do |content|
              # Ignore already filled in cells due to row/col spans
              col_index += 1 while row[col_index]

              children = content
              if content.kind_of?(Hash)
                children = content[:content]
                row_span = content[:row_span]
                col_span = content[:col_span]
              end
              cell = Cell.new(children: children, row: row_index, column: col_index,
                              row_span: row_span, col_span: col_span)
              row[col_index] = cell

              if cell.row_span > 1 || cell.col_span > 1
                row_index.upto(row_index + cell.row_span - 1) do |r|
                  @cells << [] unless @cells[r]
                  col_index.upto(col_index + cell.col_span - 1) do |c|
                    @cells[r][c] = cell
                  end
                end
              end

              col_index += cell.col_span
            end

            @number_of_columns = col_index if @number_of_columns < col_index
          end
        end

      end

      # The Cells instance containing the data of the table.
      #
      # If this is an instance that was split from another one, the cells contain *all* the rows,
      # not just the ones for this split instance.
      #
      # Also see #start_row_index.
      attr_reader :cells

      # The Cells instance containing the header cells of the table.
      #
      # If this is a TableBox instance that was split from another one, the header cells are created
      # again through the use of +header+ block supplied to ::new.
      attr_reader :header_cells

      # The Cells instance containing the footer cells of the table.
      #
      # If this is a TableBox instance that was split from another one, the footer cells are created
      # again through the use of +footer+ block supplied to ::new.
      attr_reader :footer_cells

      # The column widths definition.
      #
      # See ::new for details.
      attr_reader :column_widths

      # The row index into the #cells from which this instance starts fitting the rows.
      #
      # This value is 0 if this instance was not split from another one. Otherwise, it contains the
      # correct start index.
      attr_reader :start_row_index

      # This value is -1 if #fit was not yet called. Otherwise it contains the row index of the last
      # row that could be fitted.
      attr_reader :last_fitted_row_index

      # Creates a new TableBox instance.
      #
      # +cells+::
      #
      #     This needs to be an array of arrays containing the data of the table. See Cells for more
      #     information on the allowed contents.
      #
      # +column_widths+::
      #
      #     An array defining the width of the columns of the table.
      #
      #     Each entry in the array may either be a positive or negative number. A positive number
      #     sets a fixed width for the respective column.
      #
      #     A negative number specifies that the respective column is auto-sized. Such columns split
      #     the remaining width (after substracting the widths of the fixed columns) proportionally
      #     among them. For example, if the column width definition is [-1, -2, -2], the first
      #     column is a fifth of the width and the other two columns are each two fifth of the
      #     width.
      #
      #     If the +cells+ definition has more columns than specified by +column_widths+, the
      #     missing entries are assumed to be -1.
      #
      # +header+::
      #
      #     A callable object that needs to accept this TableBox instance as argument and that
      #     returns an array of arrays containing the header rows.
      #
      #     The header rows are shown for the table instance and all split boxes.
      #
      # +footer+::
      #
      #     A callable object that needs to accept this TableBox instance as argument and that
      #     returns an array of arrays containing the footer rows.
      #
      #     The footer rows are shown for the table instance and all split boxes.
      def initialize(cells:, column_widths: [], header: nil, footer: nil, **kwargs)
        super(**kwargs)
        @cells = Cells.new(cells)
        @column_widths = column_widths
        @start_row_index = 0
        @last_fitted_row_index = -1
        @header = header
        @header_cells = Cells.new(header.call(self)) if header
        @footer = footer
        @footer_cells = Cells.new(footer.call(self)) if footer
      end

      # Returns +true+ if not a single row could be fit.
      def empty?
        super && (!@last_fitted_row_index || @last_fitted_row_index < 0)
      end

      # Fits the table into the available space.
      def fit(available_width, available_height, _frame)
        return false if (@initial_width > 0 && @initial_width > available_width) ||
          (@initial_height > 0 && @initial_height > available_height)

        width = (@initial_width > 0 ? @initial_width : available_width) - reserved_width
        height = (@initial_height > 0 ? @initial_height : available_height) - reserved_height
        used_height = 0
        columns = calculate_column_widths(width)

        @special_cells_fit_not_successful = false
        [@header_cells, @footer_cells].each do |special_cells|
          next unless special_cells
          special_used_height, last_fitted_row_index = special_cells.fit_rows(0, height, columns)
          height -= special_used_height
          used_height += special_used_height
          @special_cells_fit_not_successful = (last_fitted_row_index != special_cells.number_of_rows - 1)
          return false if @special_cells_fit_not_successful
        end

        main_used_height, @last_fitted_row_index = @cells.fit_rows(@start_row_index, height, columns)
        used_height += main_used_height

        @width = (@initial_width > 0 ? @initial_width : columns[-1].sum + reserved_width)
        @height = (@initial_height > 0 ? @initial_height : used_height + reserved_height)
        @fit_successful = (@last_fitted_row_index == @cells.number_of_rows - 1)
      end

      private

      # Calculates and returns the x-coordinates and widths of all columns based on the given total
      # available width.
      #
      # If it is not possible to fit all columns into the given +width+, an empty array is returned.
      def calculate_column_widths(width)
        @column_widths.concat([-1] * (@cells.number_of_columns - @column_widths.size))
        fixed_width, variable_width = @column_widths.partition(&:positive?).map {|c| c.sum(&:abs) }
        rest_width = width - fixed_width
        return [] if rest_width <= 0

        variable_width_unit = rest_width / variable_width.to_f
        position = 0
        @column_widths.map do |column|
          result = column > 0 ? [position, column] : [position, column.abs * variable_width_unit]
          position += result[1]
          result
        end
      end

      # Splits the content of the column box. This method is called from Box#split.
      def split_content(_available_width, _available_height, _frame)
        if @special_cells_fit_not_successful || @last_fitted_row_index < 0
          [nil, self]
        else
          box = create_split_box
          box.instance_variable_set(:@start_row_index, @last_fitted_row_index + 1)
          box.instance_variable_set(:@last_fitted_row_index, -1)
          box.instance_variable_set(:@special_cells_fit_not_successful, nil)
          box.instance_variable_set(:@header_cells, @header ? Cells.new(@header.call(self)) : nil)
          box.instance_variable_set(:@footer_cells, @footer ? Cells.new(@footer.call(self)) : nil)
          [self, box]
        end
      end

      # Draws the child boxes onto the canvas at position [x, y].
      def draw_content(canvas, x, y)
        y += content_height
        if @header_cells
          @header_cells.draw_rows(0, -1, canvas, x, y)
          y -= @header_cells[-1, 0].top + @header_cells[-1, 0].height
        end
        @cells.draw_rows(@start_row_index, @last_fitted_row_index, canvas, x, y)
        if @footer_cells
          y -= @cells[@last_fitted_row_index, 0].top + @cells[@last_fitted_row_index, 0].height
          @footer_cells.draw_rows(0, -1, canvas, x, y)
        end
      end

    end

  end
end
