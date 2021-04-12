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

require 'hexapdf/cli/command'
require 'strscan'

module HexaPDF
  module CLI

    # Processes a PDF that contains an interactive form (AcroForm).
    class Form < Command

      def initialize #:nodoc:
        super('form', takes_commands: false)
        short_desc("Show form fields and fill out a form")
        long_desc(<<~EOF)
          Use this command to process interactive PDF forms.

          If the the output file name is not given, all form fields are listed in page order. Use
          the global --verbose option to show additional information like field type and location.

          If the output file name is given, the fields can be filled out interactively, via a
          template or just flattened by using the respective options. Form field flattening can also
          be activated in addition to filling out the form. If neither --fill, --template nor
          --flatten is specified, --fill is implied.
        EOF

        options.on("--password PASSWORD", "-p", String,
                   "The password for decryption. Use - for reading from standard input.") do |pwd|
          @password = (pwd == '-' ? read_password : pwd)
        end
        options.on("--fill", "Fill out the form") do
          @fill = true
        end
        options.on("--template TEMPLATE_FILE", "-t TEMPLATE_FILE",
                   "Use the template file for the field values (implies --fill)") do |template|
          @template = template
          @fill = true
        end
        options.on('--flatten', 'Flatten the form fields') do
          @flatten = true
        end
        options.on("--[no-]viewer-override", "Let the PDF viewer override the visual " \
                   "appearance. Default: use setting from input PDF") do |need_appearances|
          @need_appearances = need_appearances
        end
        options.on("--[no-]incremental-save", "Append the changes instead of rewriting the " \
                   "whole file. Default: true") do |incremental|
          @incremental = incremental
        end

        @password = nil
        @fill = false
        @flatten = false
        @template = nil
        @need_appearances = nil
        @incremental = true
      end

      def execute(in_file, out_file = nil) #:nodoc:
        maybe_raise_on_existing_file(out_file) if out_file
        if (@fill || @flatten) && !out_file
          raise "Output file missing"
        end
        with_document(in_file, password: @password, out_file: out_file,
                      incremental: @incremental) do |doc|
          if !doc.acro_form
            raise "This PDF doesn't contain an interactive form"
          elsif out_file
            doc.acro_form[:NeedAppearances] = @need_appearances unless @need_appearances.nil?
            if @fill || !@flatten
              if @template
                fill_form_with_template(doc)
              else
                fill_form(doc)
              end
            end
            if @flatten
              unless doc.acro_form.flatten.empty?
                $stderr.puts "Warning: Not all form fields could be flattened"
                doc.catalog.delete(:AcroForm)
                doc.delete(doc.acro_form)
              end
            end
          else
            list_form_fields(doc)
          end
        end
      end

      private

      # Lists all terminal form fields.
      def list_form_fields(doc)
        current_page_index = -1
        each_field(doc) do |_page, page_index, field, widget|
          if current_page_index != page_index
            puts "Page #{page_index + 1}"
            current_page_index = page_index
          end

          field_name = field.full_field_name +
            (field.alternate_field_name ? " (#{field.alternate_field_name})" : '')
          concrete_field_type = field.concrete_field_type
          nice_field_type = concrete_field_type.to_s.split('_').map(&:capitalize).join(' ')
          position = "(#{widget[:Rect].left}, #{widget[:Rect].bottom})"

          puts "  #{field_name}"
          if command_parser.verbosity_info?
            printf("    └─ %-22s | %-20s\n", nice_field_type, position)
          end
          puts "    └─ #{field.field_value.inspect}"
          if command_parser.verbosity_info?
            if field.field_type == :Ch
              puts "    └─ Options: #{field.option_items.map(&:inspect).join(', ')}"
            elsif concrete_field_type == :radio_button
              puts "    └─ Options: #{field.radio_button_values.map(&:inspect).join(', ')}"
            end
          end
        end
      end

      # Fills out the form by interactively asking the user for field values.
      def fill_form(doc)
        current_page_index = -1
        each_field(doc) do |_page, page_index, field, _widget|
          if current_page_index != page_index
            puts "Page #{page_index + 1}"
            current_page_index = page_index
          end

          field_name = field.full_field_name +
            (field.alternate_field_name ? " (#{field.alternate_field_name})" : '')
          concrete_field_type = field.concrete_field_type

          puts "  #{field_name}"
          puts "    └─ Current value: #{field.field_value.inspect}"

          if field.field_type == :Ch
            puts "    └─ Possible values: #{field.option_items.map(&:inspect).join(', ')}"
          elsif concrete_field_type == :radio_button
            puts "    └─ Possible values: #{field.radio_button_values.map(&:inspect).join(', ')}"
          elsif concrete_field_type == :check_box
            puts "    └─ Possible values: y(es), t(rue); n(o), f(alse)"
          end

          begin
            print "    └─ New value: "
            value = $stdin.readline.chomp
            next if value.empty?
            apply_field_value(field, value)
          rescue HexaPDF::Error => e
            puts "       ⚠  #{e.message}"
            retry
          end
        end
      end

      # Fills out the form using the data from the provided template file.
      def fill_form_with_template(doc)
        data = parse_template
        form = doc.acro_form
        data.each do |name, value|
          field = form.field_by_name(name)
          raise "Field '#{name}' not found in input PDF" unless field
          apply_field_value(field, value)
        end
      end

      # Parses the data from the given template file.
      def parse_template
        data = {}
        scanner = StringScanner.new(File.read(@template))
        until scanner.eos?
          field_name = scanner.scan(/(\\:|[^:])*?:/)
          break unless field_name
          field_name.gsub!(/\\:/, ':')
          field_value = scanner.scan(/.*?(?=^\S|\z)/m)
          data[field_name.chop] = field_value.strip.gsub(/^\s*/, '') if field_value
        end
        if !scanner.eos? && command_parser.verbosity_warning?
          $stderr.puts "Warning: Some template could not be parsed"
        end
        data
      end

      # Applies the given value to the field.
      def apply_field_value(field, value)
        case field.concrete_field_type
        when :single_line_text_field
          field.field_value = value
        when :combo_box, :list_box
          field.field_value = value
        when :editable_combo_box
          field.field_value = value
        when :check_box
          unless value.match?(/y(es)?|t(rue)?|f(alse)?|n(o)/)
            raise HexaPDF::Error, "Invalid input, use one of the possible values"
          end
          field.field_value = value.match?(/y(es)?|t(rue)?/)
        when :radio_button
          field.field_value = value.intern
        else
          raise "Field type not yet supported"
        end
      end

      # Iterates over all non-push button fields in page order. If a field appears on multiple
      # pages, it is only yielded on the first page.
      def each_field(doc) # :yields: page, page_index, field
        seen = {}

        doc.pages.each_with_index do |page, page_index|
          page[:Annots]&.each do |annotation|
            next unless annotation[:Subtype] == :Widget
            field = annotation.form_field
            next if field.concrete_field_type == :push_button
            unless seen[field]
              yield(page, page_index, field, annotation)
              seen[field] = true
            end
          end
        end
      end

    end

  end
end
