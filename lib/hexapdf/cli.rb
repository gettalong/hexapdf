# -*- encoding: utf-8 -*-
#
#--
# This file is part of HexaPDF.
#
# HexaPDF - A Versatile PDF Creation and Manipulation Library For Ruby
# Copyright (C) 2016 Thomas Leitner
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
#++

require 'io/console'
require 'cmdparse'
require 'hexapdf/cli/info'
require 'hexapdf/cli/extract'
require 'hexapdf/cli/inspect'
require 'hexapdf/cli/modify'
require 'hexapdf/version'
require 'hexapdf/document'

module HexaPDF

  # Contains the code for the +hexapdf+ binary. The binary uses the cmdparse library
  # (http://cmdparse.gettalong.org) for the command suite support.
  module CLI

    # Runs the CLI application.
    def self.run(args = ARGV)
      Application.new.parse(args)
    end

    # The CmdParse::CommandParser class that is used for running the CLI application.
    class Application < CmdParse::CommandParser

      def initialize #:nodoc:
        super(handle_exceptions: :no_help)
        main_command.options.program_name = "hexapdf"
        main_command.options.version = HexaPDF::VERSION
        add_command(HexaPDF::CLI::Info.new)
        add_command(HexaPDF::CLI::Extract.new)
        add_command(HexaPDF::CLI::Inspect.new)
        add_command(HexaPDF::CLI::Modify.new)
        add_command(CmdParse::HelpCommand.new)
        add_command(CmdParse::VersionCommand.new)
      end

      # Parses the pages specification string and returns an array containing the requested page
      # numbers.
      #
      # The parameter +count+ needs to be the total number of pages in the document.
      def parse_pages_specification(range, count)
        range.split(',').map do |str|
          case str
          when /\A[1-9]\d*\z/
            str.to_i - 1
          when /\A([1-9]\d*|e)-([1-9]\d*|e)\z/
            start_nr = ($1 == 'e' ? count : $1.to_i) - 1
            end_nr = ($2 == 'e' ? count : $2.to_i) - 1
            if start_nr > end_nr
              (end_nr..start_nr).to_a.reverse
            else
              (start_nr..end_nr).to_a
            end
          when 'e'
            count - 1
          else
            raise OptionParser::InvalidArgument, "invalid page range format: #{str}"
          end
        end.flatten
      end

      # Reads a password from the standard input and falls back to the console if needed.
      #
      # The optional argument +prompt+ can be used to customize the prompt when reading from the
      # console.
      def read_password(prompt = "Password")
        if $stdin.tty?
          read_from_console(prompt)
        else
          pwd = $stdin.gets
          pwd = read_from_console(prompt) unless pwd
          pwd.chomp
        end
      end

      private

      # Displays the given prompt, reads from the console without echo and returns the read string.
      def read_from_console(prompt)
        IO.console.write("#{prompt}: ")
        str = IO.console.noecho {|io| io.gets.chomp}
        puts
        str
      end
    end

  end

end
