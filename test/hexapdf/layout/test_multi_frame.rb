# -*- encoding: utf-8 -*-

require 'test_helper'
require 'hexapdf/layout/multi_frame'
require 'hexapdf/layout'

describe HexaPDF::Layout::MultiFrame do
  before do
    frames = [
      HexaPDF::Layout::Frame.new(0, 0, 100, 100),
      HexaPDF::Layout::Frame.new(100, 100, 50, 50),
    ]
    @multi_frame = HexaPDF::Layout::MultiFrame.new(frames)
  end

  def fit_box(count, width: 10, height: 10)
    ibox = HexaPDF::Layout::InlineBox.create(width: width, height: height) {}
    @multi_frame.fit(HexaPDF::Layout::TextBox.new(items: [ibox] * count))
  end

  def check_result(*pos, content_heights:, successful: true, boxes_remain: false)
    pos.each_slice(2).with_index do |(x, y), index|
      assert_equal(x, @multi_frame.fit_results[index].x)
      assert_equal(y, @multi_frame.fit_results[index].y)
    end
    assert_equal(content_heights, @multi_frame.content_heights)
    successful ? assert(@multi_frame.fit_successful?) : refute(@multi_frame.fit_successful?)
    rboxes = @multi_frame.remaining_boxes.empty?
    boxes_remain ? refute(rboxes) : assert(rboxes)
  end

  it "successfully places boxes only in one column" do
    fit_box(20)
    fit_box(20)
    check_result(0, 80, 0, 60, content_heights: [40, 0])
  end

  it "successfully places boxes in multiple columns, without splitting" do
    fit_box(1, height: 80)
    fit_box(1, height: 40)
    check_result(0, 20, 100, 110, content_heights: [80, 40])
  end

  it "successfully places boxes in multiple columns, with splitting" do
    fit_box(80)
    fit_box(30)
    fit_box(10)
    check_result(0, 20, 0, 0, 100, 130, 100, 110, content_heights: [100, 40])
  end

  it "fails when some boxes can't be fitted" do
    fit_box(80)
    fit_box(40)
    fit_box(20)
    fit_box(20)
    check_result(0, 20, 0, 0, 100, 110, 100, 100, successful: false, boxes_remain: true,
                 content_heights: [100, 50])
    assert_equal(2, @multi_frame.remaining_boxes.size)
  end
end
