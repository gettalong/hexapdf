# -*- encoding: utf-8 -*-

require 'test_helper'
require 'hexapdf/document'
require 'hexapdf/layout/table_box'

describe HexaPDF::Layout::TableBox::Cell do
  def create_cell(**kwargs)
    HexaPDF::Layout::TableBox::Cell.new(row: 1, column: 1, **kwargs)
  end

  describe "initialize" do
    it "creates a new instance with the given arguments" do
      cell = create_cell(children: [:a], row: 5, column: 3, row_span: 7, col_span: 2,
                         style: {background_color: 'blue'})
      assert_equal([:a], cell.children)
      assert_equal(5, cell.row)
      assert_equal(3, cell.column)
      assert_equal(7, cell.row_span)
      assert_equal(2, cell.col_span)
      assert_equal('blue', cell.style.background_color)
    end

    it "uses defaults for attributes that were not given" do
      cell = create_cell
      assert_equal(1, cell.row_span)
      assert_equal(1, cell.col_span)
    end
  end

  describe "update_height" do
    it "updates the height to the correct one" do
      cell = create_cell(children: HexaPDF::Layout::Box.create(width: 10, height: 10))
      cell.fit(100, 100, nil)
      assert_equal(10, cell.height)
      cell.update_height(50)
      assert_equal(50, cell.height)
    end

    it "fails if #fit was not yet called" do
      err = assert_raises(HexaPDF::Error) { create_cell.update_height(10) }
      assert_match(/invoke #fit first/, err.message)
    end

    it "fails if the given height is smaller than the one determined during #fit" do
      cell = create_cell(children: HexaPDF::Layout::Box.create(width: 10, height: 10))
      cell.fit(100, 100, nil)
      err = assert_raises(HexaPDF::Error) { cell.update_height(5) }
      assert_match(/at least as big/, err.message)
    end
  end

  describe "fit" do
    it "fits a single box" do
      cell = create_cell(children: HexaPDF::Layout::Box.create(width: 20, height: 10))
      cell.fit(100, 100, nil)
      assert_equal(100, cell.width)
      assert_equal(10, cell.height)
      assert_equal(20, cell.preferred_width)
      assert_equal(10, cell.preferred_height)
    end

    it "fits a single box with horizontal aligning not being :left" do
      cell = create_cell(children: HexaPDF::Layout::Box.create(width: 20, height: 10, position_hint: :center))
      cell.fit(100, 100, nil)
      assert_equal(60, cell.preferred_width)
    end

    it "fits multiple boxes" do
      box1 = HexaPDF::Layout::Box.create(width: 20, height: 10)
      box2 = HexaPDF::Layout::Box.create(width: 50, height: 15)
      cell = create_cell(children: [box1, box2])
      cell.fit(100, 100, nil)
      assert_equal(100, cell.width)
      assert_equal(25, cell.height)
      assert_equal(50, cell.preferred_width)
      assert_equal(25, cell.preferred_height)
    end

    it "fits multiple boxes with horizontal aligning not being :left" do
      box1 = HexaPDF::Layout::Box.create(width: 20, height: 10, position_hint: :center)
      box2 = HexaPDF::Layout::Box.create(width: 50, height: 15)
      cell = create_cell(children: [box1, box2])
      cell.fit(100, 100, nil)
      assert_equal(60, cell.preferred_width)
    end
  end

  describe "draw" do
    it "draws the boxes at the correct location" do
      @canvas = HexaPDF::Document.new.pages.add.canvas
      draw_block = lambda {|canvas, _| canvas.move_to(0, 0).end_path }
      box1 = HexaPDF::Layout::Box.create(width: 20, height: 10, position_hint: :center, &draw_block)
      box2 = HexaPDF::Layout::Box.create(width: 50, height: 15, &draw_block)
      box = create_cell(children: [box1, box2])
      box.fit(100, 100, nil)
      box.draw(@canvas, 10, 75)
      operators = [[:save_graphics_state],
                   [:concatenate_matrix, [1, 0, 0, 1, 50, 90]],
                   [:move_to, [0, 0]],
                   [:end_path],
                   [:restore_graphics_state],
                   [:save_graphics_state],
                   [:concatenate_matrix, [1, 0, 0, 1, 10, 75]],
                   [:move_to, [0, 0]],
                   [:end_path],
                   [:restore_graphics_state]]
      assert_operators(@canvas.contents, operators)
    end
  end

  it "returns a useful representation when inspecting" do
    cell = create_cell(row: 3, column: 2, row_span: 2, col_span: 3, children: [:a, "b"])
    assert_equal("<Cell (3,2) 2x3 [Symbol, String]>", cell.inspect)
  end
end

describe HexaPDF::Layout::TableBox::Cells do
  def create_cells(data)
    HexaPDF::Layout::TableBox::Cells.new(data)
  end

  describe "intialize" do
    it "works with simple data" do
      cells = create_cells([[:a]])
      assert_equal(1, cells.number_of_columns)
      assert_equal(1, cells.number_of_rows)
      assert_equal(:a, cells[0, 0].children)

      cells = create_cells([[:a, :b, :c]])
      assert_equal(3, cells.number_of_columns)
      assert_equal(1, cells.number_of_rows)
      assert_equal(:a, cells[0, 0].children)
      assert_equal(:b, cells[0, 1].children)
      assert_equal(:c, cells[0, 2].children)

      cells = create_cells([[:a], [:b], [:c]])
      assert_equal(1, cells.number_of_columns)
      assert_equal(3, cells.number_of_rows)
      assert_equal(:a, cells[0, 0].children)
      assert_equal(:b, cells[1, 0].children)
      assert_equal(:c, cells[2, 0].children)

      cells = create_cells([[:a, :b], [:c, :d, :e], [:f]])
      assert_equal(3, cells.number_of_columns)
      assert_equal(3, cells.number_of_rows)
      assert_equal(:a, cells[0, 0].children)
      assert_equal(:b, cells[0, 1].children)
      assert_nil(cells[0, 2])
      assert_equal(:c, cells[1, 0].children)
      assert_equal(:d, cells[1, 1].children)
      assert_equal(:e, cells[1, 2].children)
      assert_equal(:f, cells[2, 0].children)
      assert_nil(cells[2, 1])
      assert_nil(cells[2, 2])
    end

    it "can handle column spans" do
      cells = create_cells([[{col_span: 2, content: :a}, :b], [:c, {col_span: 3, content: :d}]])
      assert_equal(4, cells.number_of_columns)
      assert_equal(2, cells.number_of_rows)
      assert_equal(:a, cells[0, 0].children)
      assert_same(cells[0, 0], cells[0, 1])
      assert_equal(:b, cells[0, 2].children)
      assert_equal(:c, cells[1, 0].children)
      assert_equal(:d, cells[1, 1].children)
      assert_same(cells[1, 1], cells[1, 2])
      assert_same(cells[1, 1], cells[1, 3])
    end

    it "can handle row spans" do
      cells = create_cells([[{row_span: 2, content: :a}, :b], [{row_span: 2, content: :c}], [:d]])
      assert_equal(2, cells.number_of_columns)
      assert_equal(3, cells.number_of_rows)
      assert_equal(:a, cells[0, 0].children)
      assert_equal(:b, cells[0, 1].children)
      assert_same(cells[0, 0], cells[1, 0])
      assert_equal(:c, cells[1, 1].children)
      assert_equal(:d, cells[2, 0].children)
      assert_same(cells[1, 1], cells[2, 1])
    end

    it "can handle column and row spans concurrently" do
      cells = create_cells([[:a, {col_span: 2, content: :b}, :c],
                            [{col_span: 2, row_span: 2, content: :d}, :e, :f],
                            [{row_span: 2, content: :g}, :h],
                            [:i, :j, :k]])
      assert_equal(:a, cells[0, 0].children)
      assert_equal(:b, cells[0, 1].children)
      assert_same(cells[0, 1], cells[0, 2])
      assert_equal(:c, cells[0, 3].children)
      assert_equal(:d, cells[1, 0].children)
      assert_same(cells[1, 0], cells[1, 1])
      assert_equal(:e, cells[1, 2].children)
      assert_equal(:f, cells[1, 3].children)
      assert_same(cells[1, 0], cells[2, 0])
      assert_same(cells[1, 0], cells[2, 1])
      assert_equal(:g, cells[2, 2].children)
      assert_equal(:h, cells[2, 3].children)
      assert_equal(:i, cells[3, 0].children)
      assert_equal(:j, cells[3, 1].children)
      assert_same(cells[2, 2], cells[3, 2])
      assert_equal(:k, cells[3, 3].children)
    end

    it "sets the correct information on the created cells" do
      cells = create_cells([[:a, {col_span: 2, content: :b}],
                            [{col_span: 2, row_span: 2, content: :c}, {row_span: 2, content: :d}]])
      assert_equal(0, cells[0, 0].row)
      assert_equal(0, cells[0, 0].column)
      assert_equal(1, cells[0, 0].row_span)
      assert_equal(1, cells[0, 0].col_span)
      assert_equal(0, cells[0, 1].row)
      assert_equal(1, cells[0, 1].column)
      assert_equal(1, cells[0, 1].row_span)
      assert_equal(2, cells[0, 1].col_span)
      assert_equal(1, cells[1, 0].row)
      assert_equal(0, cells[1, 0].column)
      assert_equal(2, cells[1, 0].row_span)
      assert_equal(2, cells[1, 0].col_span)
      assert_equal(1, cells[1, 2].row)
      assert_equal(2, cells[1, 2].column)
      assert_equal(2, cells[1, 2].row_span)
      assert_equal(1, cells[1, 2].col_span)
    end
  end

  describe "each_row" do
    it "allows iterating over rows" do
      cells = create_cells([[:a, :b], [:c], [:d, :e]])
      assert_equal([[:a, :b], [:c], [:d, :e]], cells.each_row.map {|cols| cols.map(&:children) })
    end

    it "can iterate from a given start index onwards" do
      cells = create_cells([[:a, :b], [:c], [:d, :e]])
      assert_equal([[:d, :e]], cells.each_row(2).map {|cols| cols.map(&:children) })
    end
  end
end

describe HexaPDF::Layout::TableBox do
  before do
    @frame = HexaPDF::Layout::Frame.new(0, 0, 100, 100)
    draw_block = lambda {|canvas, _box| canvas.move_to(0, 0).end_path }
    @fixed_size_boxes = 15.times.map { HexaPDF::Layout::Box.new(width: 20, height: 10, &draw_block) }
  end

  def create_box(**kwargs)
    HexaPDF::Layout::TableBox.new(cells: [@fixed_size_boxes[0, 2], @fixed_size_boxes[2, 2]], **kwargs)
  end

  def check_box(box, does_fit, width, height, cell_data = nil)
    assert(does_fit == box.fit(@frame.available_width, @frame.available_height, @frame), "box didn't fit")
    assert_equal(width, box.width, "box width")
    assert_equal(height, box.height, "box height")
    if cell_data
      cells = box.cells.each_row.to_a.flatten
      assert_equal(cells.size, cell_data.size)
      cell_data.each_with_index do |(left, top, cwidth, cheight), index|
        cell = cells[index]
        assert(left == cell.left, "cell #{index} left") # may be nil
        assert(top == cell.top, "cell #{index} top")    # may be nil
        assert_equal(cwidth, cell.width, "cell #{index} width")
        assert_equal(cheight, cell.height, "cell #{index} height")
      end
    end
  end

  describe "initialize" do
    it "creates a new instance with the given arguments" do
      box = create_box(cells: [[:a, :b], [:c]], column_widths: [-2, -1])
      assert_equal([[:a, :b], [:c]], box.cells.each_row.map {|cols| cols.map(&:children) })
      assert_equal([-2, -1], box.column_widths)
      assert_equal(0, box.start_row_index)
      assert_equal(-1, box.last_fitted_row_index)
      refute(box.supports_position_flow?)
    end
  end

  describe "empty?" do
    it "is empty if nothing is fit yet" do
      assert(create_box.empty?)
    end

    it "is empty if not as single row fits" do
      box = create_box(column_widths: [5])
      box.fit(@frame.available_width, @frame.available_height, @frame)
      assert(box.empty?)
    end

    it "is not empty if at least one box fits" do
      box = create_box
      box.fit(@frame.available_width, @frame.available_height, @frame)
      refute(box.empty?)
    end
  end

  describe "fit" do
    it "respects the set initial width" do
      box = create_box(width: 50)
      box.fit(@frame.available_width, @frame.available_height, @frame)
      assert_equal(50, box.width)
    end

    it "respects the set initial height" do
      box = create_box(height: 50)
      box.fit(@frame.available_width, @frame.available_height, @frame)
      assert_equal(50, box.height)
    end

    it "respects the border and padding" do
      box = create_box(column_widths: [30, 30], style: {border: {width: [5, 4, 3, 2]}, padding: [5, 4, 3, 2]})
      box.fit(@frame.available_width, @frame.available_height, @frame)
      assert_equal(72, box.width)
      assert_equal(36, box.height)
    end

    it "cannot fit the table if the available width smaller than the initial width" do
      box = create_box(width: 200)
      refute(box.fit(@frame.available_width, @frame.available_height, @frame))
    end

    it "cannot fit the table if the available height smaller than the initial height" do
      box = create_box(height: 200)
      refute(box.fit(@frame.available_width, @frame.available_height, @frame))
    end

    it "fits a simple table" do
      check_box(create_box, true, 100, 20,
                [[0, 0, 50, 10], [50, 0, 50, 10], [0, 10, 50, 10], [50, 10, 50, 10]])
    end

    it "fits a table with column and row spans" do
      cells = [[@fixed_size_boxes[0], {col_span: 2, content: @fixed_size_boxes[1]}, @fixed_size_boxes[2]],
               [{col_span: 2, row_span: 2, content: @fixed_size_boxes[3]}, *@fixed_size_boxes[4, 2]],
               [{row_span: 2, content: @fixed_size_boxes[6]}, @fixed_size_boxes[7]],
               @fixed_size_boxes[8, 3]]
      check_box(create_box(cells: cells), true, 100, 40,
                [[0, 0, 25, 10], [25, 0, 50, 10], [25, 0, 50, 10], [75, 0, 25, 10],
                 [0, 10, 50, 20], [0, 10, 50, 20], [50, 10, 25, 10], [75, 10, 25, 10],
                 [0, 10, 50, 20], [0, 10, 50, 20], [50, 20, 25, 20], [75, 20, 25, 10],
                 [0, 30, 25, 10], [25, 30, 25, 10], [50, 20, 25, 20], [75, 30, 25, 10]])
    end

    it "partially fits a table if not enough height is available" do
      check_box(create_box(height: 10), false, 100, 10,
                [[0, 0, 50, 10], [50, 0, 50, 10], [nil, nil, 50, 10], [nil, nil, 0, 0]])
    end
  end

  describe "split" do
    it "splits the table if some rows could not be fit into the available region" do
      box = create_box
      refute(box.fit(100, 10, nil))
      box_a, box_b = box.split(100, 10, nil)
      assert_same(box_a, box)
      assert(box_b.split_box?)

      assert_equal(0, box_a.start_row_index)
      assert_equal(0, box_a.last_fitted_row_index)
      assert_equal(1, box_b.start_row_index)
      assert_equal(-1, box_b.last_fitted_row_index)
    end
  end

  describe "draw_content" do
    before do
      @canvas = HexaPDF::Document.new.pages.add.canvas
    end

    it "draws the result onto the canvas" do
      box = create_box
      box.fit(100, 100, nil)
      box.draw(@canvas, 20, 10)
      operators = [[:save_graphics_state],
                   [:concatenate_matrix, [1, 0, 0, 1, 20, 20]],
                   [:move_to, [0, 0]],
                   [:end_path],
                   [:restore_graphics_state],
                   [:save_graphics_state],
                   [:concatenate_matrix, [1, 0, 0, 1, 70.0, 20]],
                   [:move_to, [0, 0]],
                   [:end_path],
                   [:restore_graphics_state],
                   [:save_graphics_state],
                   [:concatenate_matrix, [1, 0, 0, 1, 20, 10]],
                   [:move_to, [0, 0]],
                   [:end_path],
                   [:restore_graphics_state],
                   [:save_graphics_state],
                   [:concatenate_matrix, [1, 0, 0, 1, 70.0, 10]],
                   [:move_to, [0, 0]],
                   [:end_path],
                   [:restore_graphics_state]]
      assert_operators(@canvas.contents, operators)
    end

    it "correctly works for split boxes" do
      box = create_box
      refute(box.fit(100, 10, nil))
      _, split_box = box.split(100, 10, nil)
      assert(split_box.fit(100, 100, nil))

      box.draw(@canvas, 20, 10)
      split_box.draw(@canvas, 0, 50)
      operators = [[:save_graphics_state],
                   [:concatenate_matrix, [1, 0, 0, 1, 20, 10]],
                   [:move_to, [0, 0]],
                   [:end_path],
                   [:restore_graphics_state],
                   [:save_graphics_state],
                   [:concatenate_matrix, [1, 0, 0, 1, 70.0, 10]],
                   [:move_to, [0, 0]],
                   [:end_path],
                   [:restore_graphics_state],
                   [:save_graphics_state],
                   [:concatenate_matrix, [1, 0, 0, 1, 0, 50]],
                   [:move_to, [0, 0]],
                   [:end_path],
                   [:restore_graphics_state],
                   [:save_graphics_state],
                   [:concatenate_matrix, [1, 0, 0, 1, 50.0, 50]],
                   [:move_to, [0, 0]],
                   [:end_path],
                   [:restore_graphics_state]]
      assert_operators(@canvas.contents, operators)
    end
  end
end
