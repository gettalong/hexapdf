# -*- encoding: utf-8 -*-

module HexaPDF
  module PDF

    # == Overview
    #
    # The Type module contains implementations of the types defined in the PDF specification.
    #
    # Each type class is derived from either the Dictionary class or the Stream class, depending on
    # whether the type has an associated stream.
    module Type

      autoload(:XRefStream, 'hexapdf/pdf/type/xref_stream')
      autoload(:ObjectStream, 'hexapdf/pdf/type/object_stream')
      autoload(:Trailer, 'hexapdf/pdf/type/trailer')
      autoload(:Info, 'hexapdf/pdf/type/info')
      autoload(:Catalog, 'hexapdf/pdf/type/catalog')
      autoload(:ViewerPreferences, 'hexapdf/pdf/type/viewer_preferences')
      autoload(:PageTreeNode, 'hexapdf/pdf/type/page_tree_node')
      autoload(:Page, 'hexapdf/pdf/type/page')
      autoload(:Names, 'hexapdf/pdf/type/names')
      autoload(:FileSpecification, 'hexapdf/pdf/type/file_specification')
      autoload(:EmbeddedFile, 'hexapdf/pdf/type/embedded_file')
      autoload(:Resources, 'hexapdf/pdf/type/resources')
      autoload(:GraphicsStateParameter, 'hexapdf/pdf/type/graphics_state_parameter')

    end

  end
end
