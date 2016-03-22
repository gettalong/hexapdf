# -*- encoding: utf-8 -*-

require 'hexapdf/cli'

module HexaPDF
  module CLI

    # Extracts files from a PDF file.
    #
    # See: HexaPDF::Type::EmbeddedFileStream
    class Extract < CmdParse::Command

      def initialize #:nodoc:
        super('extract', takes_commands: false)
        short_desc("Extracts files")
        long_desc(<<-EOF.gsub!(/^ */, ''))
          This command extracts files embedded in a PDF file. If the option --indices is not given,
          the available files are listed with their names and indices. The --indices option can then
          be used to extract one or more files.
        EOF
        options.on("--password PASSWORD", "-p", String, "The password for decryption") do |pwd|
          @password = pwd
        end
        options.on("--indices a,b,c", "-i a,b,c", Array,
                   "The indices of the files that should be extracted") do |indices|
          @indices = indices.map(&:to_i)
        end
        @indices = []
        @password = ''
      end

      def execute(file) #:nodoc:
        HexaPDF::Document.open(file, decryption_opts: {password: @password}) do |doc|
          if @indices.empty?
            list_files(doc)
          else
            extract_files(doc)
          end
        end
      end

      private

      # Outputs the list of files embedded in the given PDF document.
      def list_files(doc)
        each_file(doc) do |index, obj|
          $stdout.write(sprintf("%4i: %s", index, obj.path))
          ef_stream = obj.embedded_file_stream
          if (params = ef_stream[:Params]) && !params.empty?
            data = []
            data << "size: #{params[:Size]}" if params.key?(:Size)
            data << "md5: #{params[:CheckSum].unpack('H*').first}" if params.key?(:CheckSum)
            data << "ctime: #{params[:CreationDate]}" if params.key?(:CreationDate)
            data << "mtime: #{params[:ModDate]}" if params.key?(:ModDate)
            $stdout.write(" (#{data.join(', ')})")
          end
          $stdout.puts
          $stdout.puts("      #{obj[:Desc]}") if obj[:Desc] && !obj[:Desc].empty?
        end
      end

      # Extracts the files with the given indices.
      def extract_files(doc)
        each_file(doc) do |index, obj|
          next unless @indices.include?(index)
          puts "Extracting #{obj.path}..."
          File.open(obj.path, 'wb') do |file|
            fiber = obj.embedded_file_stream.stream_decoder
            while fiber.alive? && (data = fiber.resume)
              file << data.freeze
            end
          end
        end
      end

      # Iterates over all embedded files.
      def each_file(doc) # :yields: index, obj
        index = 0
        doc.each(current: false) do |obj|
          if obj.type == :Filespec && obj.key?(:EF) && !obj[:EF].empty?
            index += 1
            yield(index, obj)
          end
        end
      end

    end

  end
end
