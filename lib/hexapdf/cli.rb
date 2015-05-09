# -*- encoding: utf-8 -*-

require 'cmdparse'
require 'hexapdf/cli/info'
require 'hexapdf/version'
require 'hexapdf/pdf/document'

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
        add_command(CmdParse::HelpCommand.new)
        add_command(CmdParse::VersionCommand.new)
      end

    end

  end

end
