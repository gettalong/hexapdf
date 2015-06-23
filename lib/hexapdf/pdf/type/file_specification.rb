# -*- encoding: utf-8 -*-

require 'uri'
require 'hexapdf/pdf/filter'
require 'hexapdf/pdf/dictionary'
require 'hexapdf/pdf/stream'
require 'hexapdf/pdf/type/embedded_file'

module HexaPDF
  module PDF
    module Type

      # Represents a file specification dictionary.
      #
      # File specifications are used to refer to other files or URLs from within a PDF file. Simple
      # file specifications are just strings. However, the are automatically converted on access to
      # a full file specification to provide a unified interface.
      #
      # == Working with File Specifications
      #
      # A file specification may refer to a file or an URL. This can easily be checked with #url?.
      # Independent of whether the file specification referes to an URL or a file, the #path method
      # returns the "best" useable path for it.
      #
      # Modifying a file specification should be done via the #path= and #url= methods as they
      # ensure that no obsolescent entries are used and the file specification is consistent.
      #
      # Finally, since embedded files in a PDF document are always linked to a file specification it
      # is useful to provide embedding/unembedding operations in this class, see #embed and
      # #unembed.
      #
      # See: PDF1.7 s7.11
      class FileSpecification < Dictionary

        # The type used for the /EF field of a FileSpecification
        class EmbeddedFileParams < Dictionary

          define_field :F,    type: EmbeddedFile
          define_field :UF,   type: EmbeddedFile
          define_field :DOS,  type: EmbeddedFile
          define_field :Mac,  type: EmbeddedFile
          define_field :Unix, type: EmbeddedFile

        end


        define_field :Type, type: Symbol, default: :Filespec, required: true
        define_field :FS,   type: Symbol
        define_field :F,    type: String
        define_field :UF,   type: String, version: '1.7'
        define_field :DOS,  type: PDFByteString
        define_field :Mac,  type: PDFByteString
        define_field :Unix, type: PDFByteString
        define_field :ID,   type: Array
        define_field :V,    type: Boolean, version: '1.2'
        define_field :EF,   type: EmbeddedFileParams, version: '1.7'
        define_field :RF,   type: Dictionary, version: '1.3'
        define_field :Desc, type: String, version: '1.6'
        define_field :CI,   type: Dictionary, version: '1.7'


        # Returns +true+ if this file specification references an URL and not a file.
        def url?
          self[:FS] == :URL
        end

        # Returns the path for the referenced file or URL. An empty string is returned if no file
        # specification string is set.
        #
        # If multiple file specification strings are available, the fields are search in the
        # following order and the first one with a value is used: /UF, /F, /Unix, /Mac, /DOS.
        #
        # The encoding of the returned path string is either UTF-8 (for /UF and /F) or BINARY (for
        # /Unix, /Mac and /DOS).
        def path
          tmp = (self[:UF] || self[:F] || self[:Unix] || self[:Mac] || self[:DOS] || '').dup
          tmp.gsub!(/\\\//, "/")  # PDF1.7 s7.11.2.1 but / in filename is interpreted as separator!
          tmp.gsub!(/\\/, "/") # always use slashes instead of back-slashes!
          tmp
        end

        # Sets the file specification string to the given filename.
        #
        # Since the /Unix, /Mac and /DOS fields are obsolescent, only the /F and /UF fields are set.
        def path=(filename)
          self[:UF] = self[:F] = filename
          delete(:FS)
          delete(:Unix)
          delete(:Mac)
          delete(:DOS)
        end

        # Sets the file specification string to the given URL and updates the file system entry
        # appropriately.
        #
        # The provided URL needs to be in an RFC1738 compliant string representation. If not, an
        # error is raised.
        def url=(url)
          begin
            URI(url)
          rescue URI::InvalidURIError => e
            raise HexaPDF::Error.new(e)
          end
          self.path = url
          self[:FS] = :URL
        end

        # Returns the embedded file associated with this file specification, or +nil+ if this file
        # specification references no embedded file.
        #
        # If there are multiple possible embedded files, the /EF fields are search in the following
        # order and the first one with a value is used: /UF, /F, /Unix, /Mac, /DOS.
        def embedded_file_stream
          return unless key?(:EF)
          ef = self[:EF]
          ef[:UF] || ef[:F] || ef[:Unix] || ef[:Mac] || ef[:DOS]
        end

        # Embeds the given file into the PDF file, sets the path accordingly and returns the created
        # EmbeddedFileStream object. If there was already a file embedded for this file
        # specification, it is unembedded first.
        #
        # Options:
        #
        # name::
        #     The name that should be used as path value and when registering. Defaults to the
        #     basename of the filename if not explicitly set.
        #
        # filter::
        #     A stream filter name or an array of such that should be used for the embedded file
        #     stream. See PDF1.7 s7.4.1
        #
        # register::
        #     Specifies whether the embedded file will be added to the EmbeddedFiles name tree under
        #     the +name+. If the name is already taken, it's value is overwritten.
        #
        # The file has to be available until the PDF document gets written because reading and
        # writing is done lazily.
        def embed(filename, name: File.basename(filename), filter: :FlateDecode, register: true)
          unless File.exist?(filename)
            raise HexaPDF::Error, "No file named '#{filename}' exists"
          end
          unembed
          self.path = name

          ef_stream = (self[:EF] ||= {})[:F] = document.add({}, type: :EmbeddedFile)
          stat = File.stat(filename)
          ef_stream[:Params] = {Size: stat.size, CreationDate: stat.ctime, ModDate: stat.mtime}
          ef_stream.set_filter(filter)
          fiber_proc = proc do
            File.open(filename, 'rb') do |file|
              io_fiber = Filter.source_from_io(file, chunk_size: config['io.chunk_size'])
              while io_fiber.alive? && (io_data = io_fiber.resume)
                Fiber.yield(io_data)
              end
            end
          end
          ef_stream.stream = HexaPDF::PDF::StreamData.new(fiber_proc, length: stat.size)

          if register
            (document.catalog[:Names] ||= {})[:EmbeddedFiles] = {}
            document.catalog[:Names][:EmbeddedFiles].add_name(name, self)
          end

          ef_stream
        end

        # Deletes any embedded file stream associated with this file specification. A possible entry
        # in the EmbeddedFiles name tree is also deleted.
        def unembed
          return unless key?(:EF)
          self[:EF].each {|_key, ef_stream| document.delete(ef_stream)}

          if document.catalog.key?(:Names) && document.catalog[:Names].key?(:EmbeddedFiles)
            tree = document.catalog[:Names][:EmbeddedFiles]
            tree.each_tree_entry.find_all {|_, spec| document.deref(spec) == self}.each do |name, _|
              tree.delete_name(name)
            end
          end
        end

      end

    end
  end
end
