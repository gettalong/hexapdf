# -*- encoding: utf-8 -*-

require 'hexapdf/error'
require 'hexapdf/pdf/document'

module HexaPDF
  module PDF
    module ImageLoader

      # This module is used for loading the first page of a PDF file and use it like an image.
      #
      # The last part, "use it like an image", means that the /Matrix of the created Form XObject is
      # automatically set to scale the PDF page to the unit square of of user space. Then it can be
      # treated like any other image by specifying the needed proportions.
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
        # Creates a PDF form XObject from the PDF file or IO stream that can be used like any image.
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
          form[:Matrix] = [1.0 / form.box[2], 0, 0, 1.0 / form.box[3], 0, 0]
          document.add(document.import(form))
        end

      end

    end
  end
end
