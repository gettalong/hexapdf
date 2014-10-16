# -*- encoding: utf-8 -*-

require 'hexapdf/error'
require 'hexapdf/pdf/parser'
require 'hexapdf/pdf/reference'
require 'hexapdf/pdf/object'
require 'hexapdf/pdf/stream'
require 'hexapdf/pdf/revision'

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

      # The default configuration for a PDF document.
      #
      # The configuration contains options that can change the built-in behavior of the base classes
      # on which a document is built or which are used to read or write it.
      #
      # Available configuration keys:
      #
      # filter.map::
      #    A mapping from a PDF name (a Symbol) to a filter object (see Filter). If the value is a
      #    String, it should contain the name of a constant that contains a filter object.
      #
      # object.map::
      #    A mapping from [Type, Subtype] entries to PDF object classes. If the value is a String,
      #    it should contain the name of a constant that contains a PDF object class.
      #
      #    This mapping is used to provide automatic wrapping of objects in the #wrap method.
      def self.default_config
        {
          # See PDF1.7 s7.4.1, ADB sH.3 3.3
          'filter.map' => {
            ASCIIHexDecode: 'HexaPDF::PDF::Filter::ASCIIHexDecode',
            AHx: 'HexaPDF::PDF::Filter::ASCIIHexDecode',
            ASCII85Decode: 'HexaPDF::PDF::Filter::ASCII85Decode',
            A85: 'HexaPDF::PDF::Filter::ASCII85Decode',
            LZWDecode: 'HexaPDF::PDF::Filter::LZWDecode',
            LZW: 'HexaPDF::PDF::Filter::LZWDecode',
            FlateDecode: 'HexaPDF::PDF::Filter::FlateDecode',
            Fl: 'HexaPDF::PDF::Filter::FlateDecode',
            RunLengthDecode: 'HexaPDF::PDF::Filter::RunLengthDecode',
            RL: 'HexaPDF::PDF::Filter::RunLengthDecode',
            CCITTFaxDecode: nil,
            CCF: nil,
            JBIG2Decode: nil,
            DCTDecode: 'HexaPDF::PDF::Filter::DCTDecode',
            DCT: 'HexaPDF::PDF::Filter::DCTDecode',
            JPXDecode: 'HexaPDF::PDF::Filter::JPXDecode',
            Crypt: nil
          },
          'object.map' => {
          },
        }
      end

      # The configuration for the document.
      attr_reader :config

      # Create a new PDF document.
      #
      # Parameters:
      #
      # io:: If an IO object is provided, then this document can read PDF objects from this IO
      #      object, otherwise it can only contain created PDF objects.
      #
      # config:: A hash with configuration options that is deep-merged into the default
      #          configuration options hash (see ::default_config), meaning that direct sub-hashes
      #          are merge instead of overwritten.
      def initialize(config: {}, io: nil)
        @config = self.class.default_config.merge(config) do |k, old, new|
          old.kind_of?(Hash) && new.kind_of?(Hash) ? old.merge(new) : new
        end
        @revisions = []

        if io
          @parser = HexaPDF::PDF::Parser.new(io, self)
          @revisions << load_revision(@parser.startxref_offset)
        else
          @parser = nil
          add_revision
        end

        @next_oid = @revisions.first.trailer.value[:Size] || 1
      end

      # :call-seq:
      #   doc.object(ref)           -> obj or nil
      #   doc.object(oid, gen=0)    -> obj or nil
      #
      # Return the current version of the indirect object for the given reference or for the given
      # object and generation numbers.
      #
      # For references to unknown objects, +nil+ is returned.
      #
      # Note that free objects are represented by a PDF Null object, not +nil+!
      #
      # See: PDF1.7 s7.3.9
      def object(ref, gen = 0)
        ref = Reference.new(ref, gen) unless ref.kind_of?(Reference)

        obj = nil
        each_revision do |rev|
          # Check uses oid because we are only interested in the current version of an object with a
          # given object number!
          next unless rev.object?(ref.oid)
          obj = rev.object(ref)
          break
        end
        obj
      end

      # Dereference the given object.
      #
      # Return the object itself if it is not a reference, or the indirect object specified by the
      # reference.
      def deref(obj)
        obj.kind_of?(Reference) ? object(obj) : obj
      end

      # :call-seq:
      #   doc.object?(ref)           -> true or false
      #   doc.object?(oid, gen=0)    -> true or false
      #
      # Return +true+ if the the document contains an indirect object for the given reference or for
      # the given object and generation numbers.
      #
      # *Note* that even though this method might return +true+ for some references, #object may
      # return +nil+ because this method takes *all* revisions into account. Also see the discussion
      # on #each for more information.
      def object?(ref, gen = 0)
        ref = Reference.new(ref, gen) unless ref.kind_of?(Reference)
        each_revision.any? {|rev| rev.object?(ref)}
      end

      # :call-seq:
      #   doc.add(obj, revision: :current)     -> indirect_object
      #
      # Add the object to the specified revision of the document and return the wrapped indirect
      # object.
      #
      # If +revision+ is +:current+, the current revision is used. Otherwise +revision+ should be a
      # revision index.
      #
      # The object can either be a native Ruby object (Hash, Array, Integer, ...) or a
      # HexaPDF::PDF::Object.
      def add(obj, revision: :current)
        obj = wrap(obj) unless obj.kind_of?(HexaPDF::PDF::Object)

        revision = (revision == :current ? current_revision : @revisions[revision])
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
            raise HexaPDF::Error, "Can't add object because the specified revision already has an object " +
              "with object number #{obj.oid}"
          end
        end

        if obj.oid == 0
          obj.oid = @next_oid
          @next_oid += 1
        end

        revision.add(obj)
      end

      # :call-seq:
      #   doc.delete(ref, revision: :all)
      #   doc.delete(oid, gen=0, revision: :all)
      #
      # Delete the indirect object specified via a reference or object and generation numbers from
      # the document.
      #
      # The parameter +revision+ specifies from which revisions the object should be deleted:
      #
      # :all:: Delete the object from all revisions.
      # :current:: Delete the object only from the current revision.
      def delete(ref, gen = 0, revision: :all)
        ref = Reference.new(ref, gen) unless ref.kind_of?(Reference)
        case revision
        when :current
          current_revision.delete(ref)
        when :all
          each_revision {|rev| rev.delete(ref)}
        else
          raise HexaPDF::Error, "Unsupported parameter revision=#{revision}"
        end
      end

      # Wrap the given object inside a HexaPDF::PDF::Object class which allows one to use
      # convenience functions to work with the object.
      #
      # Note that the +obj+ parameter can also be a HexaPDF::PDF::Object object so that it can be
      # re-wrapped if needed.
      #
      # The class of the returned object is always a subclass of HexaPDF::PDF::Object (or of
      # HexaPDF::PDF::Stream if a +stream+ is given). Which subclass is used, depends on the values
      # of the +type+ and +subtype+ parameters and the 'object.map' configuration option.
      #
      # Parameters:
      #
      # :type:: (Symbol) The type of a PDF object that should be used for wrapping. This could be,
      #         for example, :Pages.
      #
      # :sub_type:: (Symbol) The subtype of a PDF object which further qualifies a type. For
      #             example, image objects in PDF have a type of :XObject and a subtype of :Image.
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
          stream ||= obj.raw_stream
          obj = obj.value
        end

        default = (stream ? HexaPDF::PDF::Stream : HexaPDF::PDF::Object)
        if obj.kind_of?(Hash)
          type ||= obj[:Type]
          subtype ||= obj[:Subtype]
        end

        klass = config['object.map'][[type, subtype]] || default
        klass = ::Object.const_get(klass) if klass.kind_of?(String)

        obj = klass.new(obj, document: self)
        obj.oid = oid if oid
        obj.gen = gen if gen
        obj.stream = stream if stream
        obj
      end

      # Recursively unwrap the object to get native Ruby objects (i.e. Hash, Array, Integer, ...
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
            object.each_with_object({}) {|(key, val), memo| memo[key] = recurse.call(val, seen)}
          when Array
            seen[object] = true
            object.map {|inner_o| recurse.call(inner_o, seen)}
          when HexaPDF::PDF::Object
            seen[object] = true
            recurse.call(object.value, seen)
          else
            object
          end
        end
        recurse.call(obj, {})
      end

      # :call-seq:
      #   doc.each(current: true) {|obj| block }   -> doc
      #   doc.each(current: true)                  -> Enumerator
      #
      # Call the given block once for every object in the PDF document.
      #
      # By default, only the current version of each object is returned which implies that each
      # object number is yielded exactly once. If +current+ is +false+, all stored objects from
      # newest to oldest are returned, not only the current version of each object.
      #
      # The +current+ parameter can make a difference because the document can contain multiple
      # revisions:
      #
      # * Multiple revisions may contain objects with the same object and generation numbers, e.g.
      #   two (different) objects with oid/gen [3,0].
      #
      # * Additionally, there may also be objects with the same object number but different
      #   generation numbers in different revisions, e.g. one object with oid/gen [3,0] and one with
      #   oid/gen [3,1].
      def each(current: true)
        return to_enum(__method__, current: current) unless block_given?

        oids = {}
        each_revision do |rev|
          rev.each do |obj|
            next if current && oids.include?(obj.oid)
            yield(obj)
            oids[obj.oid] = true
          end
        end
        self
      end

      # Load the indirect object, specified by the reference using the given cross-reference entry,
      # from the underlying IO object. The returned object is already correctly wrapped.
      #
      # For information about the +xref_entry+ parameter, have a look at XRefTable::Entry.
      #
      # *Note*: This method should in most cases *not* be used directly!
      def load_object_from_io(ref, xref_entry)
        raise_on_missing_parser

        obj, oid, gen, stream = case xref_entry[:type]
                                when :used
                                  @parser.parse_indirect_object(xref_entry[:pos])
                                when :free
                                  [nil, ref.oid, ref.gen, nil]
                                when :compressed
                                  raise "Object streams are not implemented yet"
                                else
                                  raise HexaPDF::Error, "Invalid cross-reference type '#{xref_entry[:type]}' encountered"
                                end

        if ref.oid != 0 && (oid != ref.oid || gen != ref.gen)
          raise HexaPDF::MalformedPDFError.new("The oid,gen (#{oid},#{gen}) values of the indirect object don't " +
                                               "match the values (#{ref.oid}, #{ref.gen}) from the xref table")
        end

        wrap(obj, oid: oid, gen: gen, stream: stream)
      end

      # :category: Revision Management
      #
      # Add a new empty revision to the document and return it.
      def add_revision
        if @revisions.empty?
          trailer = {}
        else
          trailer = current_revision.trailer.value.dup
          trailer.delete(:Prev)
          trailer.delete(:XRefStm)
        end

        rev = Revision.new(self, trailer: wrap(trailer, type: :Trailer))
        @revisions.push(rev)
        rev
      end

      # :category: Revision Management
      #
      # Delete a revision from the document, either by index or by specifying the revision object
      # itself.
      #
      # Note that the oldest revision has index 0 and the current revision the highest index!
      #
      # Returns the deleted revision object, or +nil+ if the index was out of range or no matching
      # revision was found.
      def delete_revision(index_or_rev)
        load_all_revisions
        if @revisions.length == 1
          raise HexaPDF::Error, "A document must have a least one revision, can't delete last one"
        elsif index_or_rev.kind_of?(Integer)
          @revisions.delete_at(index_or_rev)
        else
          @revisions.delete(index_or_rev)
        end
      end

      private

      # Raises an error if no parser is associated with the document.
      def raise_on_missing_parser
        unless @parser
          raise HexaPDF::Error, "No underlying IO object, can't load indirect object!"
        end
      end

      # :category: Revision Management
      #
      # Return the current revision.
      def current_revision
        @revisions.last
      end

      # :category: Revision Management
      #
      # Iterate over all revisions from current to oldest one, potentially loading revisions for
      # cross-reference tables/streams of an underlying PDF file.
      def each_revision
        return to_enum(__method__) unless block_given?

        i = @revisions.length - 1
        while i >= 0
          yield(@revisions[i])
          i += load_previous_revisions(i)
          i -= 1
        end
        self
      end

      # :category: Revision Management
      #
      # Load all available revisions of the document.
      def load_all_revisions
        each_revision {}
      end

      # :category: Revision Management
      #
      # :call-seq:
      #   doc.load_previous_revisions(i)     -> int
      #
      # Load the directly previous revisions for the already loaded revision at position +i+ and
      # return the number of newly added revisions (0, 1 or 2).
      #
      # Previous revisions are denoted by the :Prev and :XRefStm keys of the trailer.
      def load_previous_revisions(i)
        i = @revisions.length + i if i < 0
        rev = @revisions[i]
        @loaded_revisions ||= {}
        return 0 if @loaded_revisions.key?(rev)

        # PDF1.7 s7.5.5 states that :Prev needs to be indirect, Adobe's reference 3.4.4 says it
        # should be direct. Adobe's POV is followed here. Same with :XRefStm.
        xrefstm = @revisions[i].trailer.value[:XRefStm]
        prev = @revisions[i].trailer.value[:Prev]
        revisions = [(load_revision(prev) if prev), (load_revision(xrefstm) if xrefstm)].compact
        @revisions.insert(i, *revisions)
        @loaded_revisions[rev] = true

        revisions.length
      end

      # :category: Revision Management
      #
      # Load a single Revision whose cross-reference table/stream is located at the given position.
      def load_revision(pos)
        raise_on_missing_parser
        xref_table, trailer = if @parser.xref_table?(pos)
                                @parser.parse_xref_table_and_trailer(pos)
                              else
                                obj = load_object(Reference.new(0, 0), {type: :used, pos: pos})
                                if !obj.value.kind_of?(Hash) || obj.value[:Type] != :XRef
                                  raise HexaPDF::MalformedPDFError.new("Object is not a cross-reference stream", pos)
                                end
                                [obj.xref_table, obj.value]
                              end
        Revision.new(self, xref_table: xref_table, trailer: wrap(trailer, type: :Trailer))
      end

    end

  end
end
