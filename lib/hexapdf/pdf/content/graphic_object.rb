# -*- encoding: utf-8 -*-

require 'hexapdf/pdf/utils/math_helpers'

module HexaPDF
  module PDF
    module Content

      # == Overview
      #
      # This module contains classes describing graphic objects that can be drawn on a Canvas.
      #
      # Since the PDF specification only provides the most common path creation operators, more
      # complex graphic objects need more than one operator for their creation. By defining this
      # graphic object interface (see below) such complex objects can be drawn in a consistent
      # manner on a Canvas.
      #
      # A graphic object should only use the path creation methods or other graphic objects when it
      # is drawn. Stroking and filling, or optionally clipping, is left to the user.
      #
      # The Canvas class provides a Canvas#draw method that can be used to draw complex graphic
      # objects as well as a Canvas#graphic_object method to retrieve an instance of a graphic
      # object for custom use. The latter method uses graphic object factories that can be
      # registered via a name using the document specific 'graphic_object.map' configuration option.
      #
      # == Implementation of a Graphic Object
      #
      # Graphic objects are normally implemented as classes since this automatically allows using
      # the class itself as the graphic object's factory.
      #
      # A graphic object factory is an object that responds to #configure(**kwargs) and returns a
      # configured graphic object. When the factory is implemented as a class, the #configure method
      # should be a class method returning properly configured instances of the class.
      #
      # A graphic object itself has to respond to two methods:
      #
      # #configure(**kwargs)::
      #     This method is used for re-configuring the graphic object and it should return the
      #     graphic object itself, not a new object.
      #
      # #draw(canvas)::
      #     This method is used for drawing the graphic object on the given Canvas.
      module GraphicObject

        autoload(:Arc, 'hexapdf/pdf/content/graphic_object/arc')
        autoload(:SolidArc, 'hexapdf/pdf/content/graphic_object/solid_arc')

      end

    end
  end
end
