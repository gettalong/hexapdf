# -*- encoding: utf-8 -*-

require 'hexapdf/pdf/configuration'

module HexaPDF
  module PDF

    # This class provides utility functions for PDF documents. It is available through the
    # Document#utils method.
    #
    # Some functions can't be attributed to a single "manager" object. For example, while embedding
    # a file can be done within a Filespec object, loading an image from a file as a PDF object
    # doesn't have such a place. Such functions are available via this class.
    class DocumentUtils

      # This module provides methods for managing the images embedded in a PDF file; images
      # themselves are represented by the Type::Image class.
      #
      # Since an image can be used as a mask for another image, not all image objects found in a PDF
      # are really used as images. Such cases are all handled by this class automatically.
      module Images

        # :call-seq:
        #   images.add_image(file)            -> image
        #   images.add_image(io)              -> image
        #
        # Adds the image from the given file or IO to the PDF and returns the image object.
        def add_image(file_or_io)
          image_loader_for(file_or_io).load(@document, file_or_io)
        end

        # :call-seq:
        #   images.each_image {|image| block }   -> images
        #   images.each_image                    -> Enumerator
        #
        # Iterates over all images in the PDF.
        #
        # Note that only real images are yielded which means, for example, that images used as soft
        # mask are not.
        def each_image(&block)
          images = @document.each(current: false).select do |obj|
            obj[:Subtype] == :Image && !obj[:ImageMask]
          end
          masks = images.each_with_object([]) do |image, temp|
            temp << image[:Mask] if image[:Mask].kind_of?(Stream)
            temp << image[:SMask] if image[:SMask].kind_of?(Stream)
          end
          (images - masks).each(&block)
        end

        private

        # Returns the image loader (see ImageLoader) for the given file or IO stream or raises an
        # error if no suitable image loader is found.
        def image_loader_for(file_or_io)
          GlobalConfiguration['image_loader'].each_index do |index|
            loader = GlobalConfiguration.constantize('image_loader', index) do
              raise HexaPDF::Error, "Couldn't retrieve image loader from configuration"
            end
            return loader if loader.handles?(file_or_io)
          end

          raise HexaPDF::Error, "Couldn't find suitable image loader"
        end

      end

      include Images

      # Creates a new DocumentUtils object for the given PDF document.
      def initialize(document)
        @document = document
      end

    end

  end
end
