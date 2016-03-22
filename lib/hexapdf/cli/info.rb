# -*- encoding: utf-8 -*-

require 'hexapdf/cli'

module HexaPDF
  module CLI

    # Outputs various bits of information about PDF files:
    #
    # * The entries in the trailers /Info dictionary
    # * Encryption information from the trailers /Encrypt dictionary
    # * The number of pages
    # * The used PDF version
    #
    # See: HexaPDF::Type::Info, HexaPDF::Encryption::SecurityHandler
    class Info < CmdParse::Command

      def initialize #:nodoc:
        super('info', takes_commands: false)
        short_desc("Shows document information")
        long_desc(<<-EOF.gsub!(/^ */, ''))
          This command extracts information from the Info dictionary of a PDF file as well
          as some other useful information like the used PDF version and encryption information.
        EOF
        options.on("--password PASSOWRD", "-p", String, "The password for decryption") do |pwd|
          @password = pwd
        end
        @password = ''
        @config = {'document.auto_decrypt' => true}
      end

      def execute(file) #:nodoc:
        output_info(file)
      end

      private

      #:nodoc:
      INFO_KEYS = [:Title, :Author, :Subject, :Keywords, :Creator, :Producer,
                   :CreationDate, :ModDate]

      #:nodoc:
      COLUMN_WIDTH = 20

      def output_info(file) # :nodoc:
        HexaPDF::Document.open(file, decryption_opts: {password: @password}, config: @config) do |doc|
          INFO_KEYS.each do |name|
            next unless doc.trailer[:Info].key?(name)
            output_line(name.to_s, doc.trailer[:Info][name].to_s)
          end if @config['document.auto_decrypt']

          if doc.encrypted? && @config['document.auto_decrypt']
            details = doc.security_handler.encryption_details
            data = "yes (version: #{details[:version]}, key length: #{details[:key_length]}bits)"
            output_line("Encrypted", data)
            output_line("  String algorithm", details[:string_algorithm].to_s)
            output_line("  Stream algorithm", details[:stream_algorithm].to_s)
            output_line("  EFF algorithm", details[:embedded_file_algorithm].to_s)
            if doc.security_handler.respond_to?(:permissions)
              output_line("  Permissions", doc.security_handler.permissions.join(", "))
            end
          elsif doc.encrypted?
            output_line("Encrypted", "yes (wrong password given)")
          end

          output_line("Pages", doc.catalog[:Pages][:Count].to_s)
          output_line("Version", doc.version)
        end
      rescue HexaPDF::EncryptionError => e
        if @config['document.auto_decrypt']
          @config['document.auto_decrypt'] = false
          retry
        else
          $stderr.puts "Error while decrypting the file: #{e.message}"
          exit(1)
        end
      rescue HexaPDF::Error => e
        $stderr.puts "Error while processing '#{file}': #{e.message}"
        exit(1)
      end

      def output_line(header, text) #:nodoc:
        puts((header + ":").ljust(COLUMN_WIDTH) << text)
      end

    end

  end
end
