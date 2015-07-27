# -*- encoding: utf-8 -*-

module HexaPDF
  module PDF

    # == Overview
    #
    # An *image loader* is used for loading an image and creating a suitable PDF object. Since some
    # image information needs to be present in the PDF object itself (like height and width) the
    # loader needs to parse the image to get the needed data.
    #
    #
    # == Implementation of an Image Loader
    #
    # Each image loader is a (stateless) object (normally a module) that responds to two methods:
    #
    # handles?(file_or_io)::
    #     Should return +true+ if the given file or IO stream can be handled by the loader, i.e. if
    #     the content contains a suitable image.
    #
    # load(document, file_or_io)::
    #     Should add a new image XObject to the document that uses the file or IO stream as source
    #     and return this newly created object. This method is only invoked if #handles? has
    #     returned +true+ for the same +file_or_io+ object.
    #
    # The image XObject may use any implemented filter. For example, an image loader for JPEG files
    # would typically use the DCTDecode filter instead of decoding the image itself.
    #
    # See: PDF1.7 s8.9
    module ImageLoader

      autoload(:JPEG, 'hexapdf/pdf/image_loader/jpeg')
      autoload(:PNG, 'hexapdf/pdf/image_loader/png')

    end

  end
end
