# -*- encoding: utf-8; frozen_string_literal: true -*-
#
#--
# This file is part of HexaPDF.
#
# HexaPDF - A Versatile PDF Creation and Manipulation Library For Ruby
# Copyright (C) 2014-2020 Thomas Leitner
#
# HexaPDF is free software: you can redistribute it and/or modify it
# under the terms of the GNU Affero General Public License version 3 as
# published by the Free Software Foundation with the addition of the
# following permission added to Section 15 as permitted in Section 7(a):
# FOR ANY PART OF THE COVERED WORK IN WHICH THE COPYRIGHT IS OWNED BY
# THOMAS LEITNER, THOMAS LEITNER DISCLAIMS THE WARRANTY OF NON
# INFRINGEMENT OF THIRD PARTY RIGHTS.
#
# HexaPDF is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
# FITNESS FOR A PARTICULAR PURPOSE. See the GNU Affero General Public
# License for more details.
#
# You should have received a copy of the GNU Affero General Public License
# along with HexaPDF. If not, see <http://www.gnu.org/licenses/>.
#
# The interactive user interfaces in modified source and object code
# versions of HexaPDF must display Appropriate Legal Notices, as required
# under Section 5 of the GNU Affero General Public License version 3.
#
# In accordance with Section 7(b) of the GNU Affero General Public
# License, a covered work must retain the producer line in every PDF that
# is created or manipulated using HexaPDF.
#
# If the GNU Affero General Public License doesn't fit your need,
# commercial licenses are available at <https://gettalong.at/hexapdf/>.
#++

require 'stringio'
require 'hexapdf/error'
require 'hexapdf/content'
require 'hexapdf/configuration'
require 'hexapdf/reference'
require 'hexapdf/object'
require 'hexapdf/pdf_array'
require 'hexapdf/stream'
require 'hexapdf/revisions'
require 'hexapdf/type'
require 'hexapdf/task'
require 'hexapdf/encryption'
require 'hexapdf/writer'
require 'hexapdf/importer'
require 'hexapdf/image_loader'
require 'hexapdf/font_loader'
require 'hexapdf/layout'

begin
  require 'hexapdf/cext'
rescue LoadError
  # ignore error because the C-extension only makes things faster
end

# == HexaPDF API Documentation
#
# Here are some pointers to more in depth information:
#
# * For information about the command line application, see the HexaPDF::CLI module.
# * HexaPDF::Document provides information about how to work with a PDF file.
# * HexaPDF::Content::Canvas provides the canvas API for drawing/writing on a page or form XObject
module HexaPDF

  autoload(:Composer, 'hexapdf/composer')

  # == HexaPDF::Document
  #
  # Represents one PDF document.
  #
  # A PDF document consists of (indirect) objects, so the main job of this class is to provide
  # methods for working with these objects. However, since a PDF document may also be
  # incrementally updated and can therefore contain one or more revisions, there are also methods
  # for working with these revisions.
  #
  # Note: This class provides everything to work on PDF documents on a low-level basis. This means
  # that there are no convenience methods for higher PDF functionality. Those can be found in the
  # objects linked from here, like #catalog.
  #
  # == Known Messages
  #
  # The document object provides a basic message dispatch system via #register_listener and
  # #dispatch_message.
  #
  # Following are the messages that are used by HexaPDF itself:
  #
  # :complete_objects::
  #      This message is called before the first step of writing a document. Listeners should
  #      complete PDF objects that are missing some information.
  #
  #      For example, the font system uses this message to complete the font objects with
  #      information that is only available once all the used glyphs are known.
  #
  # :before_write::
  #      This message is called before a document is actually serialized and written.
  class Document

    autoload(:Pages, 'hexapdf/document/pages')
    autoload(:Fonts, 'hexapdf/document/fonts')
    autoload(:Images, 'hexapdf/document/images')
    autoload(:Files, 'hexapdf/document/files')

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
    # config:: A hash with configuration options that is deep-merged into the default configuration
    #          (see
    #          HexaPDF::DefaultDocumentConfiguration[../index.html#DefaultDocumentConfiguration],
    #          meaning that direct sub-hashes are merged instead of overwritten.
    def initialize(io: nil, decryption_opts: {}, config: {})
      @config = Configuration.with_defaults(config)
      @version = '1.2'

      @revisions = Revisions.from_io(self, io)
      @security_handler = if encrypted? && @config['document.auto_decrypt']
                            Encryption::SecurityHandler.set_up_decryption(self, **decryption_opts)
                          else
                            nil
                          end

      @listeners = {}
      @cache = Hash.new {|h, k| h[k] = {} }
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
      @revisions.any? {|rev| rev.object?(ref) }
    end

    # :call-seq:
    #   doc.add(obj, revision: :current, **wrap_opts)     -> indirect_object
    #
    # Adds the object to the specified revision of the document and returns the wrapped indirect
    # object.
    #
    # The object can either be a native Ruby object (Hash, Array, Integer, ...) or a
    # HexaPDF::Object. If it is not the latter, #wrap is called with the object and the
    # additional keyword arguments.
    #
    # If the +revision+ option is +:current+, the current revision is used. Otherwise +revision+
    # should be a revision index.
    def add(obj, revision: :current, **wrap_opts)
      obj = wrap(obj, **wrap_opts) unless obj.kind_of?(HexaPDF::Object)

      revision = (revision == :current ? @revisions.current : @revisions.revision(revision))
      if revision.nil?
        raise ArgumentError, "Invalid revision index specified"
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
        @revisions.each {|rev| rev.delete(ref, mark_as_free: mark_as_free) }
      else
        raise ArgumentError, "Unsupported option revision: #{revision}"
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
      if !obj.kind_of?(HexaPDF::Object) || !obj.document? || obj.document == self
        raise ArgumentError, "Importing only works for PDF objects associated " \
          "with another document"
      end
      HexaPDF::Importer.for(source: obj.document, destination: self).import(obj)
    end

    # Wraps the given object inside a HexaPDF::Object class which allows one to use
    # convenience functions to work with the object.
    #
    # The +obj+ argument can also be a HexaPDF::Object object so that it can be re-wrapped if
    # needed.
    #
    # The class of the returned object is always a subclass of HexaPDF::Object (or of
    # HexaPDF::Stream if a +stream+ is given). Which subclass is used, depends on the values of the
    # +type+ and +subtype+ options as well as on the 'object.type_map' and 'object.subtype_map'
    # global configuration options:
    #
    # * First +type+ is used to try to determine the class. If it is not provided and if +obj+ is a
    #   hash with a :Type field, the value of this field is used instead. If the resulting object is
    #   already a Class object, it is used, otherwise the type is looked up in 'object.type_map'.
    #
    # * If +subtype+ is provided or can be determined because +obj+ is a hash with a :Subtype or :S
    #   field, the type and subtype together are used to look up a special subtype class in
    #   'object.subtype_map'.
    #
    #   Additionally, if there is no +type+ but a +subtype+, all required fields of the subtype
    #   class need to have values; otherwise the subtype class is not used. This is done to better
    #   prevent invalid mappings when only partial knowledge (:Type key is missing) is available.
    #
    # * If there is no valid class after the above steps, HexaPDF::Stream is used if a stream is
    #   given, HexaPDF::Dictionary if the given object is a hash, HexaPDF::PDFArray if it is an
    #   array or else HexaPDF::Object is used.
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
      data = if obj.kind_of?(HexaPDF::Object)
               obj.data
             else
               HexaPDF::PDFData.new(obj)
             end
      data.oid = oid if oid
      data.gen = gen if gen
      data.stream = stream if stream

      if type.kind_of?(Class)
        klass = type
        type = (klass <= HexaPDF::Dictionary ? klass.type : nil)
      else
        type ||= deref(data.value[:Type]) if data.value.kind_of?(Hash)
        klass = GlobalConfiguration.constantize('object.type_map', type) { nil } if type
      end

      if data.value.kind_of?(Hash)
        subtype ||= deref(data.value[:Subtype]) || deref(data.value[:S])
      end
      if subtype
        sub_klass = GlobalConfiguration.constantize('object.subtype_map', type, subtype) { klass }
        if type ||
            sub_klass&.each_field&.none? {|name, field| field.required? && !data.value.key?(name) }
          klass = sub_klass
        end
      end

      klass ||= if data.stream
                  HexaPDF::Stream
                elsif data.value.kind_of?(Hash)
                  HexaPDF::Dictionary
                elsif data.value.kind_of?(Array)
                  HexaPDF::PDFArray
                else
                  HexaPDF::Object
                end

      klass.new(data, document: self)
    end

    # :call-seq:
    #   document.unwrap(obj)   -> unwrapped_obj
    #
    # Recursively unwraps the object to get native Ruby objects (i.e. Hash, Array, Integer, ...
    # instead of HexaPDF::Reference and HexaPDF::Object).
    def unwrap(object, seen = {})
      object = deref(object)
      object = object.data if object.kind_of?(HexaPDF::Object)
      if seen.key?(object)
        raise HexaPDF::Error, "Can't unwrap a recursive structure"
      end

      case object
      when Hash
        seen[object] = true
        object.transform_values {|value| unwrap(value, seen.dup) }
      when Array
        seen[object] = true
        object.map {|inner_o| unwrap(inner_o, seen.dup) }
      when HexaPDF::PDFData
        seen[object] = true
        unwrap(object.value, seen.dup)
      else
        object
      end
    end

    # :call-seq:
    #   doc.each(only_current: true, only_loaded: false) {|obj| block }        -> doc
    #   doc.each(only_current: true, only_loaded: false) {|obj, rev| block }   -> doc
    #   doc.each(only_current: true, only_loaded: false)                       -> Enumerator
    #
    # Calls the given block once for every object, or, if +only_loaded+ is +true+, for every loaded
    # object in the PDF document. The block may either accept only the object or the object and the
    # revision it is in.
    #
    # By default, only the current version of each object is returned which implies that each object
    # number is yielded exactly once. If the +only_current+ option is +false+, all stored objects
    # from newest to oldest are returned, not only the current version of each object.
    #
    # The +only_current+ option can make a difference because the document can contain multiple
    # revisions:
    #
    # * Multiple revisions may contain objects with the same object and generation numbers, e.g.
    #   two (different) objects with oid/gen [3,0].
    #
    # * Additionally, there may also be objects with the same object number but different
    #   generation numbers in different revisions, e.g. one object with oid/gen [3,0] and one with
    #   oid/gen [3,1].
    def each(only_current: true, only_loaded: false, &block)
      unless block_given?
        return to_enum(__method__, only_current: only_current, only_loaded: only_loaded)
      end

      yield_rev = (block.arity == 2)
      oids = {}
      @revisions.reverse_each do |rev|
        rev.each(only_loaded: only_loaded) do |obj|
          next if only_current && oids.include?(obj.oid)
          (yield_rev ? yield(obj, rev) : yield(obj))
          oids[obj.oid] = true
        end
      end
      self
    end

    # :call-seq:
    #    doc.register_listener(name, callable)             -> callable
    #    doc.register_listener(name) {|*args| block}       -> block
    #
    # Registers the given listener for the message +name+.
    def register_listener(name, callable = nil, &block)
      callable ||= block
      (@listeners[name] ||= []) << callable
      callable
    end

    # Dispatches the message +name+ with the given arguments to all registered listeners.
    #
    # See the main Document documentation for an overview of messages that are used by HexaPDF
    # itself.
    def dispatch_message(name, *args)
      @listeners[name]&.each {|obj| obj.call(*args) }
    end

    UNSET = ::Object.new # :nordoc:

    # Caches and returns the given +value+ or the value of the given block using the given
    # +pdf_data+ and +key+ arguments as composite cache key. If a cached value already exists and
    # +update+ is +false+, the cached value is just returned.
    #
    # Set +update+ to +true+ to force an update of the cached value.
    #
    # This facility can be used to cache expensive operations in PDF objects that are easy to
    # compute again.
    #
    # Use #clear_cache to clear the cache if necessary.
    def cache(pdf_data, key, value = UNSET, update: false)
      return @cache[pdf_data][key] if cached?(pdf_data, key) && !update
      @cache[pdf_data][key] = (value == UNSET ? yield : value)
    end

    # Returns +true+ if there is a value cached for the composite key consisting of the given
    # +pdf_data+ and +key+ objects.
    #
    # Also see: #cache
    def cached?(pdf_data, key)
      @cache.key?(pdf_data) && @cache[pdf_data].key?(key)
    end

    # Clears all cached data or, if a Object::PDFData object is given, just the cache for this one
    # object.
    #
    # It is *not* recommended to clear the whole cache! Better clear the cache for individual PDF
    # objects!
    #
    # Also see: #cache
    def clear_cache(pdf_data = nil)
      pdf_data ? @cache[pdf_data].clear : @cache.clear
    end

    # Returns the Pages object that provides convenience methods for working with pages.
    #
    # Also see: HexaPDF::Type::PageTreeNode
    def pages
      @pages ||= Pages.new(self)
    end

    # Returns the Images object that provides convenience methods for working with images.
    def images
      @images ||= Images.new(self)
    end

    # Returns the Files object that provides convenience methods for working with files.
    def files
      @files ||= Files.new(self)
    end

    # Returns the Fonts object that provides convenience methods for working with fonts.
    def fonts
      @fonts ||= Fonts.new(self)
    end

    # Returns the main AcroForm object for dealing with interactive forms.
    #
    # See HexaPDF::Type::Catalog#acro_form for details on the arguments.
    def acro_form(create: false)
      catalog.acro_form(create: create)
    end

    # Executes the given task and returns its result.
    #
    # Tasks provide an extensible way for performing operations on a PDF document without
    # cluttering the Document interface.
    #
    # See Task for more information.
    def task(name, **opts, &block)
      task = config.constantize('task.map', name) do
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
      trailer.catalog
    end

    # Returns the PDF document's version as string (e.g. '1.4').
    #
    # This method takes the file header version and the catalog's /Version key into account. If a
    # version has been set manually and the catalog's /Version key refers to a later version, the
    # later version is used.
    #
    # See: PDF1.7 s7.2.2
    def version
      catalog_version = (catalog[:Version] || '1.0').to_s
      (@version < catalog_version ? catalog_version : @version)
    end

    # Sets the version of the PDF document. The argument must be a string in the format 'M.N'
    # where M is the major version and N the minor version (e.g. '1.4' or '2.0').
    def version=(value)
      raise ArgumentError, "PDF version must follow format M.N" unless value.to_s.match?(/\A\d\.\d\z/)
      @version = value.to_s
    end

    # Returns +true+ if the document is encrypted.
    def encrypted?
      !trailer[:Encrypt].nil?
    end

    # Encrypts the document.
    #
    # This is done by setting up a security handler for this purpose and populating the trailer's
    # Encrypt dictionary accordingly. The actual encryption, however, is only done when writing the
    # document.
    #
    # The security handler used for encrypting is selected via the +name+ argument. All other
    # arguments are passed on the security handler.
    #
    # If the document should not be encrypted, the +name+ argument has to be set to +nil+. This
    # removes the security handler and deletes the trailer's Encrypt dictionary.
    #
    # See: HexaPDF::Encryption::SecurityHandler#set_up_encryption and
    # HexaPDF::Encryption::StandardSecurityHandler::EncryptionOptions for possible encryption
    # options.
    def encrypt(name: :Standard, **options)
      if name.nil?
        trailer.delete(:Encrypt)
        @security_handler = nil
      else
        @security_handler = Encryption::SecurityHandler.set_up_encryption(self, name, **options)
      end
    end

    # Returns the security handler that is used for decrypting or encrypting the document, or +nil+
    # if none is set.
    #
    # * If the document was created by reading an existing file and the document was automatically
    #   decrypted, then this method returns the handler for decrypting.
    #
    # * Once the #encrypt method is called, the specified security handler for encrypting is
    #   returned.
    def security_handler
      @security_handler
    end

    # Validates all objects, or, if +only_loaded+ is +true+, only loaded objects, with optional
    # auto-correction, and returns +true+ if everything is fine.
    #
    # If a block is given, it is called on validation problems.
    #
    # See HexaPDF::Object#validate for more information.
    def validate(auto_correct: true, only_loaded: false, &block) #:yield: msg, correctable, object
      result = trailer.validate(auto_correct: auto_correct, &block)
      each(only_current: false, only_loaded: only_loaded) do |obj|
        result &&= obj.validate(auto_correct: auto_correct, &block)
      end
      result
    end

    # :call-seq:
    #   doc.write(filename, incremental: false, validate: true, update_fields: true, optimize: false)
    #   doc.write(io, incremental: false, validate: true, update_fields: true, optimize: false)
    #
    # Writes the document to the given file (in case +io+ is a String) or IO stream.
    #
    # Before the document is written, it is validated using #validate and an error is raised if the
    # document is not valid. However, this step can be skipped if needed.
    #
    # Options:
    #
    # incremental::
    #   Use the incremental writing mode which just adds a new revision to an existing document.
    #   This is needed, for example, when modifying a signed PDF and the original signature should
    #   stay valid.
    #
    #   See: PDF1.7 s7.5.6
    #
    # validate::
    #   Validates the document and raises an error if an uncorrectable problem is found.
    #
    # update_fields::
    #   Updates the /ID field in the trailer dictionary as well as the /ModDate field in the
    #   trailer's /Info dictionary so that it is clear that the document has been updated.
    #
    # optimize::
    #   Optimize the file size by using object and cross-reference streams. This will raise the PDF
    #   version to at least 1.5.
    def write(file_or_io, incremental: false, validate: true, update_fields: true, optimize: false)
      dispatch_message(:complete_objects)

      if update_fields
        trailer.update_id
        trailer.info[:ModDate] = Time.now
      end

      if validate
        self.validate(auto_correct: true) do |msg, correctable, obj|
          next if correctable
          raise HexaPDF::Error, "Validation error for (#{obj.oid},#{obj.gen}): #{msg}"
        end
      end

      if optimize
        task(:optimize, object_streams: :generate)
        self.version = '1.5' if version < '1.5'
      end

      dispatch_message(:before_write)

      if file_or_io.kind_of?(String)
        File.open(file_or_io, 'w+') {|file| Writer.write(self, file, incremental: incremental) }
      else
        Writer.write(self, file_or_io, incremental: incremental)
      end
    end

  end

end
