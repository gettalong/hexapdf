# -*- encoding: utf-8 -*-

# TODO: probbly remove this file and put the information regarding the implementation of the PDF
# objects into a comment somewhere

module HexaPDF
  module PDF

    # Contains the implementation of the PDF object system.
    #
    # PDF includes eight basic object types. For usability and performance reasons these objects are
    # mapped to native Ruby objects where possible.
    #
    # However, all eight object types have corresponding constants in this module to test for them
    # if necessary.
    #
    # See: PDF1.7 s7.3
    module Object

      # The "true" object of the PDF object system.
      #
      # There is only one "true" object in PDF and it is represented by +true+.
      #
      # See: False
      # See: PDF1.7 s7.3.2
      True = true

      # The "false" object of the PDF object system.
      #
      # There is only one "false" object in PDF and it is represented by +false+.
      #
      # See: True
      # See: PDF1.7 s7.3.2
      False = false

      # Numeric objects of the PDF object system.
      #
      # There are two types of numeric object: integers and real numbers. This constant represents
      # objects of both types.
      #
      # Note that no objects of this type can be created by calling +Numeric.new+. Have a look at
      # the documentation of Integer and Real for information on how to create such objects.
      #
      # See: Integer, Real
      # See: PDF1.7 s7.3.3
      Numeric = ::Numeric

      # Integer objects of the PDF object system.
      #
      # These objects are represented by objects of class +Integer+. This means that objects can be
      # created via integer literals like +5+ or +-10+ or, for example, by the +.to_i+ method.
      #
      # Note that no objects of this type can be created by calling +Integer.new+!
      #
      # See: Numeric, Real
      # See: PDF1.7 s7.3.3
      Integer = ::Integer

      # Real objects of the PDF object system.
      #
      # These objects are represented by objects of class +Float+. This means that objects can be
      # created via float literals like +5.3+ or +-10.1234+ or, for example, by the +.to_f+ method.
      #
      # Note that no objects of this type can be created by calling +Float.new+!
      #
      # See: Numeric, Real
      # See: PDF1.7 s7.3.3
      Real = ::Float

      # String objects of the PDF object system.
      #
      # A string object in PDF is just a container for bytes, without a specific encoding or any
      # other information. It is represented by objects of class +String+.
      #
      # TODO: reference parser/writer for more information on encodings and string object types.
      #
      # See: PDF1.7 s7.3.4
      String = ::String

      # Name objects of the PDF object system.
      #
      # A name object is uniquely defined by the characters it consists of. Two name objects with
      # exactly the same character sequence are the *same* object.
      #
      # Name objects are represented by objects of class +Symbol+ which have the same semantics.
      # This means that such objects can be created via symbol literals like :Length or, for
      # example, by the +.to_sym+ method.
      #
      # Note that no objects of this type can be created by calling +Symbol.new+!
      #
      # See: PDF1.7 s7.3.5
      Name = ::Symbol

      # Array objects of the PDF object system.
      #
      # An array object in PDF is a collection of sequentially ordered objects of any type. Such
      # objects are represented by objects of class +Array+.
      #
      # See: PDF1.7. s7.3.6
      Array = ::Array

      # Dictionary objects of the PDF object system.
      #
      # A dictionary object in PDF is an unordered associative table containing object pairs where
      # one element is the *key* and the other the *value*. Keys may only be Name objects whereas
      # values can be of any type.
      #
      # Dictionary objects are represented by objects of class +Hash+.
      #
      # See: PDF1.7 s7.3.7
      Dictionary = ::Hash

      # The "null object" of the PDF object system.
      #
      # This object can only exist once and is represented by +nil+.
      #
      # See: PDF1.7 s7.3.9
      Null = nil

    end


  end
end
