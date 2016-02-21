# -*- encoding: utf-8 -*-

require 'stringio'
require 'hexapdf/error'
require 'hexapdf/pdf/configuration'
require 'hexapdf/pdf/reference'
require 'hexapdf/pdf/object'
require 'hexapdf/pdf/stream'
require 'hexapdf/pdf/revisions'
require 'hexapdf/pdf/type'
require 'hexapdf/task'
require 'hexapdf/encryption'
require 'hexapdf/pdf/writer'
require 'hexapdf/pdf/importer'
require 'hexapdf/pdf/image_loader'
require 'hexapdf/pdf/document_utils'

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

      # :call-seq:
      #   Document.open(filename, **docargs)                   -> doc
      #   Document.open(filename, **docargs) {|doc| block}     -> obj
      #
      # Creates a new PDF Document object for the given file.
      #
      # Depending on whether a block is provided, the functionality is different:
      #
      # * If no block is provided, the whole file is instantly read into memory and the PDF Document
      #   created for it is returned.
      #
      # * If a block is provided, the file is opened and a PDF Document is created for it. The
      #   created document is passed as an argument to the block and when the block returns the
      #   associated file object is closed. The value of the block will be returned.
      #
      # The block version is useful, for example, when you are dealing with a large file and you
      # only need a small portion of it.
      #
      # The provided keyword arguments (except +io+) are passed on unchanged to Document.new.
      def self.open(filename, **kwargs)
        if block_given?
          File.open(filename, 'rb') do |file|
            yield(new(**kwargs, io: file))
          end
        else
          new(**kwargs, io: StringIO.new(File.binread(filename)))
        end
      end

      # The configuration for the document.
      attr_reader :config

      # The revisions of the document.
      attr_reader :revisions

      # Creates a new PDF document, either an empty one or one read from the provided +io+.
      #
      # When an IO object is provided and it contains an encrypted PDF file, it is automatically
      # decrypted behind the scenes. The +decryption_opts+ argument has to be set appropriately in
      # this case.
      #
      # Options:
      #
      # io:: If an IO object is provided, then this document can read PDF objects from this IO
      #      object, otherwise it can only contain created PDF objects.
      #
      # decryption_opts:: A hash with options for decrypting the PDF objects loaded from the IO.
      #
      # config:: A hash with configuration options that is deep-merged into the default
      #          configuration (see DefaultDocumentConfiguration), meaning that direct sub-hashes
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
        while i >= 0
          return @revisions[i].object(ref) if @revisions[i].object?(ref)
          i -= 1
        end
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
      #   doc.add(obj, revision: :current, **wrap_opts)     -> indirect_object
      #
      # Adds the object to the specified revision of the document and returns the wrapped indirect
      # object.
      #
      # The object can either be a native Ruby object (Hash, Array, Integer, ...) or a
      # HexaPDF::PDF::Object. If it is not the latter, #wrap is called with the object and the
      # additional keyword arguments.
      #
      # If the +revision+ option is +:current+, the current revision is used. Otherwise +revision+
      # should be a revision index.
      def add(obj, revision: :current, **wrap_opts)
        obj = wrap(obj, wrap_opts) unless obj.kind_of?(HexaPDF::PDF::Object)

        revision = (revision == :current ? @revisions.current : @revisions.revision(revision))
        if revision.nil?
          raise HexaPDF::Error, "Invalid revision index specified"
        end

        if obj.document? && obj.document != self
          raise HexaPDF::Error, "Can't add object that is already attached to another document"
        end
        obj.document = self

        if obj.indirect? && (rev_obj = revision.object(obj.oid))
          if rev_obj.equal?(obj)
            return obj
          else
            raise HexaPDF::Error, "Can't add object because the specified revision already has " \
              "an object with object number #{obj.oid}"
          end
        end

        obj.oid = @revisions.map(&:next_free_oid).max unless obj.indirect?

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

      # :call-seq:
      #   doc.import(obj)     -> imported_object
      #
      # Imports the given, with a different document associated PDF object and returns the imported
      # object.
      #
      # If the same argument is provided in multiple invocations, the import is done only once and
      # the previously imoprted object is returned.
      #
      # See: Importer
      def import(obj)
        if !obj.kind_of?(HexaPDF::PDF::Object) || !obj.document? || obj.document == self
          raise HexaPDF::Error, "Importing only works for PDF objects associated " \
            "with another document"
        end
        HexaPDF::PDF::Importer.for(source: obj.document, destination: self).import(obj)
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
      # 'object.subtype_map' global configuration options:
      #
      # * If *only* +type+ or +subtype+ is provided and a mapping is found, the resulting class is
      #   used.
      #
      # * If both +type+ and +subtype+ are provided and and a mapping for +subtype+ is found, the
      #   resulting class is used. If no mapping is found but there is a mapping for +type+, the
      #   mapped class is used.
      #
      # * If there is no valid class after the above steps, HexaPDF::PDF::Stream is used if a stream
      #   is given, HexaPDF::PDF::Dictionary is used if the given objecct is a hash or else
      #   HexaPDF::PDF::Object is used.
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
        data = if obj.kind_of?(HexaPDF::PDF::Object)
                 obj.data
               else
                 HexaPDF::PDF::PDFData.new(obj)
               end
        data.oid = oid if oid
        data.gen = gen if gen
        data.stream = stream if stream

        if type.kind_of?(Class)
          klass = type
        else
          default = if data.stream
                      HexaPDF::PDF::Stream
                    elsif data.value.kind_of?(Hash)
                      HexaPDF::PDF::Dictionary
                    else
                      HexaPDF::PDF::Object
                    end
          if data.value.kind_of?(Hash)
            type ||= deref(data.value[:Type])
            subtype ||= deref(data.value[:Subtype])
          end

          if subtype
            klass = GlobalConfiguration.constantize('object.subtype_map'.freeze, subtype)
          end
          if type && !klass
            klass = GlobalConfiguration.constantize('object.type_map'.freeze, type)
          end
          klass ||= default
        end

        klass.new(data, document: self)
      end

      # :call-seq:
      #   document.unwrap(obj)   -> unwrapped_obj
      #
      # Recursively unwraps the object to get native Ruby objects (i.e. Hash, Array, Integer, ...
      # instead of HexaPDF::PDF::Reference and HexaPDF::PDF::Object).
      def unwrap(object, seen = {})
        object = deref(object)
        object = object.data if object.kind_of?(HexaPDF::PDF::Object)
        if seen.key?(object)
          raise HexaPDF::Error, "Can't unwrap a recursive structure"
        end

        case object
        when Hash
          seen[object] = true
          object.each_with_object({}) {|(key, val), memo| memo[key] = unwrap(val, seen.dup)}
        when Array
          seen[object] = true
          object.map {|inner_o| unwrap(inner_o, seen.dup)}
        when HexaPDF::PDF::PDFData
          seen[object] = true
          unwrap(object.value, seen.dup)
        else
          object
        end
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

      # Returns a DocumentUtils object that provides convenience methods for often used
      # functionality like adding images.
      def utils
        @utils ||= DocumentUtils.new(self)
      end

      # Executes the given task and returns its result.
      #
      # Tasks provide an extensible way for performing operations on a PDF document without
      # cluttering the Document interface.
      #
      # See Task for more information.
      def task(name, **opts, &block)
        task = GlobalConfiguration.constantize('task.map'.freeze, name) do
          raise HexaPDF::Error, "No task named '#{name}' is available"
        end
        task.call(self, **opts, &block)
      end

      # Returns the trailer dictionary for the document.
      def trailer
        @revisions.current.trailer
      end

      # Returns the document's catalog, the root of the object tree.
      def catalog
        trailer[:Root] ||= add({}, type: :Catalog)
      end

      # Returns the root node of the document's page tree.
      #
      # See: HexaPDF::PDF::Type::PageTreeNode
      def pages
        catalog.pages
      end

      # Returns the PDF document's version as string (e.g. '1.4').
      #
      # This method takes the file header version and the catalog's /Version key into account. If a
      # version has been set manually and the catalog's /Version key refers to a later version, the
      # later version is used.
      #
      # See: PDF1.7 s7.2.2
      def version
        catalog_version = (catalog[:Version] || '1.0'.freeze).to_s
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
          handler = GlobalConfiguration.constantize('encryption.filter_map', :Standard)
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

      # :call-seq:
      #   doc.write(filename, validate: true, update_fields: true)
      #   doc.write(io, validate: true, update_fields: true)
      #
      # Writes the document to the give file (in case +io+ is a String) or IO stream.
      #
      # Before the document is written, it is validated using the 'validate' task, and an error is
      # raised if the document is not valid. However, this step can be skipped if needed.
      #
      # Options:
      #
      # validate::
      #   Validates the document and raises an error if an uncorrectable problem is found.
      #
      # update_fields::
      #   Updates the /ID field in the trailer dictionary as well as the /ModDate field in the
      #   trailer's /Info dictionary so that it is clear that the document has been updated.
      def write(file_or_io, validate: true, update_fields: true)
        if validate
          task(:validate) do |msg, correctable|
            next if correctable
            raise HexaPDF::Error, "Validation error: #{msg}"
          end
        end
        if update_fields
          trailer.update_id
          (trailer[:Info] ||= {})[:ModDate] = Time.now
        end

        if file_or_io.kind_of?(String)
          File.open(file_or_io, 'w+') {|file| Writer.write(self, file)}
        else
          Writer.write(self, file_or_io)
        end
      end

    end

  end
end
