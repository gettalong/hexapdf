# -*- encoding: utf-8 -*-

require 'hexapdf/error'
require 'hexapdf/pdf/document'

module HexaPDF
  module PDF
    module ImageLoader

      # This module is used for loading the first page of a PDF file.
      #
      # Loaded PDF graphics are represented by form XObjects instead of image XObjects. However, the
      # image/xobject drawing methods of the Canvas know how to handle them correctly so that this
      # doesn't matter from a user's point of view.
      #
      # See: PDF1.7 s8.10
      module PDF

        # The magic marker that tells us if the file/IO contains an PDF file.
        MAGIC_FILE_MARKER = "%PDF-".force_encoding(Encoding::BINARY)

        # :call-seq:
        #   PDF.handles?(filename)     -> true or false
        #   PDF.handles?(io)           -> true or false
        #
        # Returns +true+ if the given file or IO stream can be handled, ie. if it contains an image
        # in JPEG format.
        def self.handles?(file_or_io)
          if file_or_io.kind_of?(String)
            File.read(file_or_io, 5, mode: 'rb') == MAGIC_FILE_MARKER
          else
            file_or_io.rewind
            file_or_io.read(5) == MAGIC_FILE_MARKER
          end
        end

        # :call-seq:
        #   PDF.load(document, filename)    -> form_obj
        #   PDF.load(document, io)          -> form_obj
        #
        # Creates a PDF form XObject from the PDF file or IO stream.
        #
        # See: DefaultConfiguration for the meaning of 'image_loader.pdf.use_stringio'.
        def self.load(document, file_or_io)
          idoc = if file_or_io.kind_of?(String) && document.config['image_loader.pdf.use_stringio']
                   HexaPDF::PDF::Document.open(file_or_io)
                 elsif file_or_io.kind_of?(String)
                   HexaPDF::PDF::Document.new(io: File.open(file_or_io, 'rb'))
                 else
                   HexaPDF::PDF::Document.new(io: file_or_io)
                 end
          form = idoc.pages.page(0).to_form_xobject
          document.add(document.import(form))
        end

      end

    end
  end
end
