# # Composer - Optional Content
#
# This example shows how to use the optional content feature to create a quiz
# where the answers can be individually shown and hidden. There is also a link
# after the questions to toggle all answers.
#
# Note: To provide the "All answers" layer switch functionality we need to make
# use of optional content membership dictionaries. However, this PDF feature is
# not supported by all PDF viewers. To enable the "All answers" switch in this
# example, use `a1m`, `a2m`, and `a3m` instead of `a1`, `a2`, and `a3` when
# defining the optional content for a box.
#
# Usage:
# : `ruby composer_optional_content.rb`
#
require 'hexapdf'

HexaPDF::Composer.create('composer_optional_content.pdf') do |composer|
  composer.styles(
    question: {font_size: 16, margin: [0, 0, 16], fill_color: 'hp-blue'},
    answer: {font: 'ZapfDingbats', fill_color: "green"},
  )

  oc = composer.document.optional_content
  all = oc.ocg('All answers').off!.add_to_ui
  a1 = oc.ocg('Answer 1').off!.add_to_ui
  a2 = oc.ocg('Answer 2').off!.add_to_ui
  a3 = oc.ocg('Answer 3').off!.add_to_ui
  a1m = oc.create_ocmd([a1, all], policy: :any_on)
  a2m = oc.create_ocmd([a2, all], policy: :any_on)
  a3m = oc.create_ocmd([a3, all], policy: :any_on)

  composer.text('The Great Ruby Quiz', text_align: :center, margin: [0, 0, 24],
                font: 'Helvetica bold', font_size: 24)

  composer.list(marker_type: :decimal, item_spacing: 32, style: :question) do |listing|
    listing.multiple do |item|
      item.text('Who created Ruby?', style: :question)
      item.column(columns: 3, gaps: 5) do |cols|
        cols.list(marker_type: :decimal) do |answers|
          answers.text('Guido van Rossum')
          answers.multiple do |answer|
            answer.text('Yukihiro “Matz” Matsumoto', position: :float)
            answer.text("\u{a0}\u{a0}✔", style: :answer,
                        properties: {'optional_content' => a1m})
          end
          answers.text('Rob Pike')
        end
      end
    end

    listing.multiple do |item|
      item.text('When was Ruby created?', style: :question)
      item.column(columns: 3, gaps: 5) do |cols|
        cols.list(marker_type: :decimal) do |answers|
          answers.text('1991')
          answers.text('1992')
          answers.multiple do |answer|
            answer.text('1993', position: :float)
            answer.text("\u{a0}\u{a0}✔", style: :answer,
                        properties: {'optional_content' => a2m})
          end
        end
      end
    end

    listing.multiple do |item|
      item.text('What is the best PDF library for Ruby?', style: :question)
      answer = composer.document.layout.text('There are several PDF libraries for ' \
                                             'Ruby but the best is HexaPDF! :)',
                                             width: 400,
                                             properties: {'optional_content' => a3m})
      item.formatted_text([{box: answer}], border: {width: [0, 0, 1]})
    end
  end

  action = composer.document.wrap({Type: :Action, S: :SetOCGState})
  action.add_state_change(:toggle, [a1, a2, a3])
  composer.text("Click to toggle answers", border: {width: 1, color: "red"},
                align: :right, padding: 2, overlays: [[:link, action: action]])
end
