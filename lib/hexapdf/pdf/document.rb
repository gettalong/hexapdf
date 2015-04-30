# -*- encoding: utf-8 -*-

require 'hexapdf/error'
require 'hexapdf/pdf/configuration'
require 'hexapdf/pdf/reference'
require 'hexapdf/pdf/object'
require 'hexapdf/pdf/stream'
require 'hexapdf/pdf/revisions'
require 'hexapdf/pdf/type'
require 'hexapdf/pdf/task'
require 'hexapdf/pdf/encryption'
require 'hexapdf/pdf/writer'

module HexaPDF
  module PDF

    # Represents one PDF document.
    #
    # A PDF document consists of (indirect) objects, so the main job of this class is to provide
    # methods for working with these objects. However, since a PDF document may also be
    # incrementally updated and can therefore contain one or more revisions, there are also methods
    # to work with these revisions.
    #
    # Note: This class provides everything to work on PDF documents on a low-level basis. This means
    # that there are no convenience methods for higher PDF functionality whatsoever.
    class Document

      # The configuration for the document.
      attr_reader :config

      # The revisions of the document.
      attr_reader :revisions

      # Creates a new PDF document.
      #
      # When an IO object is provided and it contains an encrypted PDF file, it is automatically
      # decrypted behind the scenes.
      #
      # Options:
      #
      # io:: If an IO object is provided, then this document can read PDF objects from this IO
      #      object, otherwise it can only contain created PDF objects.
      #
      # decryption_opts:: A hash with options for decrypting the PDF objects loaded from the IO.
      #
      # config:: A hash with configuration options that is deep-merged into the default
      #          configuration options hash (see ::default_config), meaning that direct sub-hashes
      #          are merged instead of overwritten.
      def initialize(io: nil, decryption_opts: {}, config: {})
        @config = Configuration.with_defaults(config)
        @version = '1.2'

        @revisions = Revisions.from_io(self, io)
        if encrypted?
          handler = Encryption::SecurityHandler.set_up_decryption(self, decryption_opts)
          self.security_handler = handler.dup
        else
          self.security_handler = nil
        end
      end

      # :call-seq:
      #   doc.object(ref)    -> obj or nil
      #   doc.object(oid)    -> obj or nil
      #
      # Returns the current version of the indirect object for the given exact reference or for the
      # given object number.
      #
      # For references to unknown objects, +nil+ is returned but free objects are represented by a
      # PDF Null object, not by +nil+!
      #
      # See: PDF1.7 s7.3.9
      def object(ref)
        i = @revisions.size - 1
        (return @revisions[i].object(ref) if @revisions[i].object?(ref); i -= 1) while i >= 0
        nil
      end

      # Dereferences the given object.
      #
      # Return the object itself if it is not a reference, or the indirect object specified by the
      # reference.
      def deref(obj)
        obj.kind_of?(Reference) ? object(obj) : obj
      end

      # :call-seq:
      #   doc.object?(ref)    -> true or false
      #   doc.object?(oid)    -> true or false
      #
      # Returns +true+ if the the document contains an indirect object for the given exact reference
      # or for the given object number.
      #
      # Even though this method might return +true+ for some references, #object may return +nil+
      # because this method takes *all* revisions into account. Also see the discussion on #each for
      # more information.
      def object?(ref)
        @revisions.any? {|rev| rev.object?(ref)}
      end

      # :call-seq:
      #   doc.add(obj, revision: :current)     -> indirect_object
      #
      # Adds the object to the specified revision of the document and returns the wrapped indirect
      # object.
      #
      # If the +revision+ option is +:current+, the current revision is used. Otherwise +revision+
      # should be a revision index.
      #
      # The object can either be a native Ruby object (Hash, Array, Integer, ...) or a
      # HexaPDF::PDF::Object.
      def add(obj, revision: :current)
        obj = wrap(obj) unless obj.kind_of?(HexaPDF::PDF::Object)

        revision = (revision == :current ? @revisions.current : @revisions.revision(revision))
        if revision.nil?
          raise HexaPDF::Error, "Invalid revision index specified"
        end

        if obj.document? && obj.document != self
          raise HexaPDF::Error, "Can't add object that is already attached to another document"
        end
        obj.document = self

        if obj.oid != 0 && (rev_obj = revision.object(obj.oid))
          if rev_obj.equal?(obj)
            return obj
          else
            raise HexaPDF::Error, "Can't add object because the specified revision already has " +
              "an object with object number #{obj.oid}"
          end
        end

        obj.oid = @revisions.map {|rev| rev.next_free_oid}.max if obj.oid == 0

        revision.add(obj)
      end

      # :call-seq:
      #   doc.delete(ref, revision: :all)
      #   doc.delete(oid, revision: :all)
      #
      # Deletes the indirect object specified by an exact reference or by an object number from the
      # document.
      #
      # Options:
      #
      # revision:: Specifies from which revisions the object should be deleted:
      #
      #            :all:: Delete the object from all revisions.
      #            :current:: Delete the object only from the current revision.
      #
      # mark_as_free:: If +true+, objects are only marked as free objects instead of being actually
      #                deleted.
      def delete(ref, revision: :all, mark_as_free: true)
        case revision
        when :current
          @revisions.current.delete(ref, mark_as_free: mark_as_free)
        when :all
          @revisions.each {|rev| rev.delete(ref, mark_as_free: mark_as_free)}
        else
          raise HexaPDF::Error, "Unsupported option revision=#{revision}"
        end
      end

      # Wraps the given object inside a HexaPDF::PDF::Object class which allows one to use
      # convenience functions to work with the object.
      #
      # The +obj+ argument can also be a HexaPDF::PDF::Object object so that it can be re-wrapped if
      # needed.
      #
      # The class of the returned object is always a subclass of HexaPDF::PDF::Object (or of
      # HexaPDF::PDF::Stream if a +stream+ is given). Which subclass is used, depends on the values
      # of the +type+ and +subtype+ options as well as on the 'object.type_map' and
      # 'object.subtype_map' configuration options:
      #
      # * If *only* +type+ is provided and a mapping is found, the resulting class object is used.
      # * Otherwise if only +subtype+ or both arguments are provided and a mapping for +subtype+ is
      #   found, the resulting class object is used.
      #
      # Options:
      #
      # :type:: (Symbol or Class) The type of a PDF object that should be used for wrapping. This
      #         could be, for example, :Pages. If a class object is provided, it is used directly
      #         instead of the type detection system.
      #
      # :subtype:: (Symbol) The subtype of a PDF object which further qualifies a type. For
      #            example, image objects in PDF have a type of :XObject and a subtype of :Image.
      #
      # :oid:: (Integer) The object number that should be set on the wrapped object. Defaults to 0
      #        or the value of the given object's object number.
      #
      # :gen:: (Integer) The generation number that should be set on the wrapped object. Defaults to
      #        0 or the value of the given object's generation number.
      #
      # :stream:: (String or StreamData) The stream object which should be set on the wrapped
      #           object.
      def wrap(obj, type: nil, subtype: nil, oid: nil, gen: nil, stream: nil)
        if obj.kind_of?(HexaPDF::PDF::Object)
          oid ||= obj.oid
          gen ||= obj.gen
          stream ||= obj.raw_stream if obj.respond_to?(:raw_stream)
          obj = obj.value
        end

        if type.kind_of?(Class)
          klass = type
        else
          default = if stream
                      HexaPDF::PDF::Stream
                    elsif obj.kind_of?(Hash)
                      HexaPDF::PDF::Dictionary
                    else
                      HexaPDF::PDF::Object
                    end
          if obj.kind_of?(Hash)
            type ||= obj[:Type]
            subtype ||= obj[:Subtype]
          end

          if subtype
            klass = config.constantize('object.subtype_map'.freeze, subtype)
          else
            klass = config.constantize('object.type_map'.freeze, type)
          end
          klass ||= default
        end

        opts = {document: self}
        opts[:stream] = stream if stream
        opts[:oid] = oid if oid
        opts[:gen] = gen if gen
        klass.new(obj, opts)
      end

      # Recursively unwraps the object to get native Ruby objects (i.e. Hash, Array, Integer, ...
      # instead of HexaPDF::PDF::Reference and HexaPDF::PDF::Object).
      def unwrap(obj)
        recurse = lambda do |object, seen|
          object = deref(object)
          if seen.key?(object)
            raise HexaPDF::Error, "Can't unwrap a recursive structure"
          end

          case object
          when Hash
            seen[object] = true
            object.each_with_object({}) {|(key, val), memo| memo[key] = recurse.call(val, seen.dup)}
          when Array
            seen[object] = true
            object.map {|inner_o| recurse.call(inner_o, seen.dup)}
          when HexaPDF::PDF::Object
            seen[object] = true
            recurse.call(object.value, seen.dup)
          else
            object
          end
        end
        recurse.call(obj, {})
      end

      # :call-seq:
      #   doc.each(current: true) {|obj| block }        -> doc
      #   doc.each(current: true) {|obj, rev| block }   -> doc
      #   doc.each(current: true)                       -> Enumerator
      #
      # Calls the given block once for every object in the PDF document. The block may either accept
      # only the object or the object and the revision it is in.
      #
      # By default, only the current version of each object is returned which implies that each
      # object number is yielded exactly once. If the +current+ option is +false+, all stored
      # objects from newest to oldest are returned, not only the current version of each object.
      #
      # The +current+ option can make a difference because the document can contain multiple
      # revisions:
      #
      # * Multiple revisions may contain objects with the same object and generation numbers, e.g.
      #   two (different) objects with oid/gen [3,0].
      #
      # * Additionally, there may also be objects with the same object number but different
      #   generation numbers in different revisions, e.g. one object with oid/gen [3,0] and one with
      #   oid/gen [3,1].
      def each(current: true, &block)
        return to_enum(__method__, current: current) unless block_given?

        yield_rev = (block.arity == 2)
        oids = {}
        @revisions.reverse_each do |rev|
          rev.each do |obj|
            next if current && oids.include?(obj.oid)
            (yield_rev ? yield(obj, rev) : yield(obj))
            oids[obj.oid] = true
          end
        end
        self
      end

      # Executes the given task and returns its result.
      #
      # Tasks provide an extensible way for performing operations on a PDF document without
      # cluttering the Document interface.
      #
      # See Task for more information.
      def task(name, **opts, &block)
        task = config.constantize('task.map'.freeze, name) do
          raise HexaPDF::Error, "No task named '#{name}' is available"
        end
        task.call(self, **opts, &block)
      end

      # Returns the trailer dictionary for the document.
      def trailer
        @revisions.current.trailer
      end

      # Returns the PDF documents version as string (e.g. '1.4').
      #
      # This method takes the file header version and the catalog's /Version key into account. If a
      # version has been set manually and the catalog's /Version key refers to a later version, the
      # later version is used.
      #
      # See: PDF1.7 s7.2.2
      def version
        catalog_version = (trailer[:Root][:Version] || '1.0'.freeze).to_s
        (@version < catalog_version ? catalog_version : @version)
      end

      # Sets the version of the PDF document. The argument must be a string in the format 'M.N'
      # where M is the major version and N the minor version (e.g. '1.4' or '2.0').
      def version=(value)
        raise HexaPDF::Error, "PDF version must follow format M.N" unless value.to_s =~ /\A\d\.\d\z/
        @version = value.to_s
      end

      # Returns +true+ if the document is encrypted.
      #
      # Note that a security handler might be set but that the document might not (yet) be
      # encrypted!
      def encrypted?
        !trailer[:Encrypt].nil?
      end

      # Returns the security handler that is used for decrypting or encrypting the document.
      #
      # Retrieving or setting a security handler does not automatically make a document encrypted!
      # Only when the security handler is used to set up the encryption will the document be
      # encrypted.
      #
      # If the option +use_standard_handler+ is +true+ and if no security handler has yet been set,
      # the standard security handler (i.e. the handler set as :Standard for the the configuration
      # option 'encryption.filter_map') is automatically set and used.
      def security_handler(use_standard_handler: true)
        if @security_handler.nil? && use_standard_handler
          handler = config.constantize('encryption.filter_map', :Standard)
          @security_handler = handler.new(self) if handler
        end
        @security_handler
      end

      # Sets the security handler that is used for encrypting the document.
      #
      # If the document should not be encrypted, +nil+ has to be assigned. This removes the security
      # handler and deletes the trailer's Encrypt dictionary.
      #
      # The +handler+ object has to be a subclass of Encryption::SecurityHandler.
      #
      # See: #security_handler
      def security_handler=(handler)
        @security_handler = handler
        trailer.delete(:Encrypt) if handler.nil?
      end

      # Writes the document to the IO stream.
      #
      # Before the document is written, it is validated using the 'validate' task, and an error is
      # raised if the document is not valid. However, this step can be skipped if needed.
      #
      # Options:
      #
      # validate:: Validates the document and raises an error if an uncorrectable problem is found.
      def write(io, validate: true)
        if validate
          task(:validate) do |msg, correctable|
            next if correctable
            raise HexaPDF::Error, "Validation error: #{msg}"
          end
        end
        Writer.write(self, io)
      end

    end

  end
end
