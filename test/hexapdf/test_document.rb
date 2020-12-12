# -*- encoding: utf-8 -*-

require 'tempfile'
require 'test_helper'
require 'hexapdf/document'
require 'stringio'

describe HexaPDF::Document do
  before do
    @io = StringIO.new(<<~EOF)
      %PDF-1.7
      1 0 obj
      10
      endobj

      2 0 obj
      20
      endobj

      3 0 obj
      30
      endobj

      xref
      0 4
      0000000000 65535 f 
      0000000009 00000 n 
      0000000028 00000 n 
      0000000047 00000 n 
      trailer
      << /Size 4 >>
      startxref
      66
      %%EOF

      2 0 obj
      200
      endobj

      xref
      2 2
      0000000197 00000 n 
      0000000000 00001 f 
      trailer
      << /Size 4 /Prev 66 >>
      startxref
      217
      %%EOF
    EOF
    @io_doc = HexaPDF::Document.new(io: @io)
    @doc = HexaPDF::Document.new
  end

  describe "::open" do
    before do
      @file = Tempfile.new('hexapdf-document')
      @io_doc.write(@file)
      @file.close
    end

    after do
      @file.unlink
    end

    it "works without block" do
      doc = HexaPDF::Document.open(@file.path)
      assert_equal(200, doc.object(2).value)
    end

    it "works with a block" do
      HexaPDF::Document.open(@file.path) do |doc|
        assert_equal(200, doc.object(2).value)
      end
    end
  end

  describe "initialize" do
    it "doesn't need any arguments" do
      doc = HexaPDF::Document.new
      assert_equal(:A4, doc.config['page.default_media_box'])
    end

    it "takes a configuration hash as option" do
      doc = HexaPDF::Document.new(config: {'page.default_media_box' => :A5})
      assert_equal(:A5, doc.config['page.default_media_box'])
    end

    it "takes an IO object as option" do
      doc = HexaPDF::Document.new(io: @io)
      assert_equal(10, doc.object(1).value)
    end
  end

  describe "object" do
    it "accepts a Reference object as argument" do
      assert_equal(10, @io_doc.object(HexaPDF::Reference.new(1, 0)).value)
    end

    it "accepts an object number as arguments" do
      assert_equal(10, @io_doc.object(1).value)
    end

    it "returns added objects" do
      obj = @io_doc.add(@io_doc.wrap({Type: :Test}, oid: 100))
      assert_equal(obj, @io_doc.object(100))
    end

    it "returns nil for unknown object references" do
      assert_nil(@io_doc.object(100))
    end

    it "returns only the newest version of an object" do
      assert_equal(200, @io_doc.object(2).value)
      assert_equal(200, @io_doc.object(HexaPDF::Reference.new(2, 0)).value)
      assert_nil(@io_doc.object(3).value)
      assert_nil(@io_doc.object(HexaPDF::Reference.new(3, 1)).value)
      assert_equal(30, @io_doc.object(HexaPDF::Reference.new(3, 0)).value)
    end
  end

  describe "object?" do
    it "works with a Reference object as argument" do
      assert(@io_doc.object?(HexaPDF::Reference.new(1, 0)))
    end

    it "works with an object number as arguments" do
      assert(@io_doc.object?(1))
    end
  end

  describe "deref" do
    it "returns a dereferenced object when given a Reference object" do
      assert_equal(@io_doc.object(1), @io_doc.deref(HexaPDF::Reference.new(1, 0)))
    end

    it "returns the given object when it is not a Reference object" do
      assert_equal(5, @io_doc.deref(5))
    end
  end

  describe "add" do
    it "automatically assigns free object numbers" do
      assert_equal(1, @doc.add(5).oid)
      assert_equal(2, @doc.add(5).oid)
      @doc.revisions.add
      assert_equal(3, @doc.add(5).oid)
    end

    it "assigns the object's document" do
      obj = @doc.add(5)
      assert_equal(@doc, obj.document)
    end

    it "allows adding a native ruby object" do
      obj = @doc.add(5)
      assert_equal(5, obj.value)
    end

    it "allows passing arguments to the wrap call" do
      obj = @doc.add({}, type: HexaPDF::Dictionary)
      assert_equal(HexaPDF::Dictionary, obj.class)
    end

    it "allows adding a HexaPDF::Object" do
      obj = @doc.add(HexaPDF::Object.new(5))
      assert_equal(5, obj.value)
    end

    it "returns the given object if it is already stored in the document" do
      obj = @doc.add(5)
      assert_same(obj, @doc.add(obj))
    end

    it "allows specifying a revision to which the object should be added" do
      @doc.revisions.add
      @doc.revisions.add

      @doc.add(@doc.wrap(5, oid: 1), revision: 0)
      assert_equal(5, @doc.object(1).value)

      @doc.add(@doc.wrap(10, oid: 1), revision: 2)
      assert_equal(10, @doc.object(1).value)

      @doc.add(@doc.wrap(7.5, oid: 1), revision: 1)
      assert_equal(10, @doc.object(1).value)
    end

    it "fails if the specified revision index is invalid" do
      assert_raises(ArgumentError) { @doc.add(5, revision: 5) }
    end

    it "fails if the object to be added is associated with another document" do
      doc = HexaPDF::Document.new
      obj = doc.add(5)
      assert_raises(HexaPDF::Error) { @doc.add(obj) }
    end

    it "fails if the object number is already associated with another object" do
      obj = @doc.add(5)
      assert_raises(HexaPDF::Error) { @doc.add(@doc.wrap(5, oid: obj.oid, gen: 1)) }
    end
  end

  describe "delete" do
    it "works with a Reference object as argument" do
      obj = @doc.add(5)
      @doc.delete(obj, mark_as_free: false)
      refute(@doc.object?(obj))
    end

    it "works with an object number as arguments" do
      @doc.add(5)
      @doc.delete(1, mark_as_free: false)
      refute(@doc.object?(1))
    end

    describe "with an object in multiple revisions" do
      before do
        @ref = HexaPDF::Reference.new(2, 3)
        obj = @doc.wrap(5, oid: @ref.oid, gen: @ref.gen)
        @doc.revisions.add
        @doc.add(obj, revision: 0)
        @doc.add(obj, revision: 1)
      end

      it "deletes an object for all revisions when revision = :all" do
        @doc.delete(@ref, revision: :all, mark_as_free: false)
        refute(@doc.object?(@ref))
      end

      it "deletes an object only in the current revision when revision = :current" do
        @doc.delete(@ref, revision: :current, mark_as_free: false)
        assert(@doc.object?(@ref))
      end

      it "marks the object as PDF null object when using mark_as_free=true" do
        @doc.delete(@ref, revision: :current)
        assert(@doc.object(@ref).null?)
      end
    end

    it "fails if the revision argument is invalid" do
      assert_raises(ArgumentError) { @doc.delete(1, revision: :invalid) }
    end
  end

  describe "import" do
    it "allows importing objects from another document" do
      obj = @doc.import(@io_doc.object(2))
      assert_equal(200, obj.value)
      refute_equal(0, obj.oid)
    end

    it "fails if the given object is not a PDF object" do
      assert_raises(ArgumentError) { @doc.import(5) }
    end

    it "fails if the given object is associated with no or the destination document" do
      assert_raises(ArgumentError) { @doc.import(HexaPDF::Object.new(5)) }
      obj = @doc.add(5)
      assert_raises(ArgumentError) { @doc.import(obj) }
    end
  end

  describe "wrap" do
    before do
      @myclass = Class.new(HexaPDF::Dictionary)
      @myclass.define_type(:MyClass)
      @myclass2 = Class.new(HexaPDF::Dictionary)
      @myclass2.define_field(:Test, type: String, required: true)
      HexaPDF::GlobalConfiguration['object.type_map'][:MyClass] = @myclass
      HexaPDF::GlobalConfiguration['object.subtype_map'][nil][:Global] = @myclass2
      HexaPDF::GlobalConfiguration['object.subtype_map'][:MyClass] = {TheSecond: @myclass2}
    end

    after do
      HexaPDF::GlobalConfiguration['object.type_map'].delete(:MyClass)
      HexaPDF::GlobalConfiguration['object.subtype_map'][nil].delete(:Global)
      HexaPDF::GlobalConfiguration['object.subtype_map'][:MyClass].delete(:TheSecond)
    end

    it "uses a suitable default type if no special type is specified" do
      assert_instance_of(HexaPDF::Object, @doc.wrap(5))
      assert_instance_of(HexaPDF::Stream, @doc.wrap({a: 5}, stream: ''))
      assert_instance_of(HexaPDF::Dictionary, @doc.wrap({a: 5}))
      assert_instance_of(HexaPDF::PDFArray, @doc.wrap([1, 2]))
    end

    it "returns an object of type HexaPDF::Object" do
      assert_kind_of(HexaPDF::Object, @doc.wrap(5))
      assert_kind_of(HexaPDF::Object, @doc.wrap({}, stream: ''))
    end

    it "associates the returned object with the document" do
      assert_equal(@doc, @doc.wrap(5).document)
    end

    it "sets the given object (not === HexaPDF::Object) as value for the PDF object" do
      assert_equal(5, @doc.wrap(5).value)
    end

    it "uses the data of the given PDF object for re-wrapping" do
      obj = @doc.wrap({a: :b}, oid: 10, gen: 20, stream: 'hallo')
      new_obj = @doc.wrap(obj)
      assert_equal({a: :b}, new_obj.value)
      assert_equal('hallo', new_obj.raw_stream)
      assert_equal(10, new_obj.oid)
      assert_equal(20, new_obj.gen)
      refute_same(obj, new_obj)

      obj = @doc.wrap({a: :b}, oid: 10, gen: 20)
      new_obj = @doc.wrap(obj)
      refute_same(obj, new_obj)
    end

    it "allows overrding the data of the given PDF object" do
      obj = @doc.wrap({a: :b}, oid: 10, gen: 20, stream: 'hallo')
      new_obj = @doc.wrap(obj, oid: 15, gen: 25, stream: 'not')
      assert_equal('not', new_obj.raw_stream)
      assert_equal(15, new_obj.oid)
      assert_equal(25, new_obj.gen)
    end

    it "sets the given oid/gen values on the returned object" do
      obj = @doc.wrap(5, oid: 10, gen: 20)
      assert_equal(10, obj.oid)
      assert_equal(20, obj.gen)
    end

    it "uses the type/subtype information in the hash that should be wrapped" do
      assert_kind_of(@myclass, @doc.wrap({Type: :MyClass}))
      refute_kind_of(@myclass2, @doc.wrap({Subtype: :TheSecond}))
      refute_kind_of(@myclass2, @doc.wrap({Subtype: :Global}))
      assert_kind_of(@myclass2, @doc.wrap({Subtype: :Global, Test: "true"}))
      assert_kind_of(@myclass2, @doc.wrap({Type: :MyClass, S: :TheSecond}))
      assert_kind_of(@myclass, @doc.wrap({Type: :MyClass, Subtype: :TheThird}))
    end

    it "respects the given type/subtype arguments" do
      assert_kind_of(@myclass, @doc.wrap({Type: :Other}, type: :MyClass))
      refute_kind_of(@myclass2, @doc.wrap({Subtype: :Other}, subtype: :Global))
      assert_kind_of(@myclass2, @doc.wrap({Subtype: :Other, Test: "true"}, subtype: :Global))
      assert_kind_of(@myclass2, @doc.wrap({Type: :Other, Subtype: :Other},
                                          type: :MyClass, subtype: :TheSecond))
      assert_kind_of(@myclass2, @doc.wrap({Subtype: :TheSecond}, type: @myclass))
    end

    it "directly uses a class given via the type argument" do
      obj = @doc.wrap({a: :b}, type: @myclass, oid: 5)
      assert_kind_of(@myclass, obj)
      obj = @doc.wrap(obj, type: @myclass2)
      assert_kind_of(@myclass2, obj)
      assert_equal(:b, obj.value[:a])
      assert_equal(5, obj.oid)
    end
  end

  describe "unwrap" do
    it "returns a simple native ruby type" do
      assert_equal(5, @doc.unwrap(5))
    end

    it "recursively unwraps arrays" do
      assert_equal([5, 10, [200], [200]],
                   @io_doc.unwrap([5, HexaPDF::Reference.new(1, 0), [HexaPDF::Reference.new(2, 0)],
                                   [HexaPDF::Reference.new(2, 0)]]))
    end

    it "recursively unwraps hashes" do
      assert_equal({a: 5, b: 10, c: [200], d: [200]},
                   @io_doc.unwrap({a: 5, b: HexaPDF::Reference.new(1, 0),
                                   c: [HexaPDF::Reference.new(2, 0)],
                                   d: [HexaPDF::Reference.new(2, 0)]}))
    end

    it "recursively unwraps PDF objects" do
      assert_equal({a: 10}, @io_doc.unwrap(@io_doc.wrap({a: HexaPDF::Reference.new(1, 0)})))
      value = {a: HexaPDF::Object.new({b: HexaPDF::Object.new(10)})}
      assert_equal({a: {b: 10}}, @doc.unwrap(value))
    end

    it "fails to unwrap recursive structures" do
      obj1 = @doc.add({})
      obj2 = @doc.add({})
      obj1.value[2] = obj2
      obj2.value[1] = obj1
      assert_raises(HexaPDF::Error) { @doc.unwrap({a: obj1}) }
    end
  end

  describe "each" do
    it "iterates over the current objects" do
      assert_equal([10, 200, nil], @io_doc.each(only_current: true).sort.map(&:value))
    end

    it "iterates over all objects" do
      assert_equal([10, 200, 20, 30, nil], @io_doc.each(only_current: false).sort.map(&:value))
    end

    it "iterates over all loaded objects" do
      assert_equal(200, @io_doc.object(2).value)
      assert_equal([200], @io_doc.each(only_loaded: true).sort.map(&:value))
    end

    it "yields the revision as second argument if the block accepts exactly two arguments" do
      objs = [[10, 20, 30], [200, nil]]
      data = @io_doc.revisions.map.with_index {|rev, i| objs[i].map {|o| [o, rev] } }.reverse.flatten
      @io_doc.each(only_current: false) do |obj, rev|
        assert(data.shift == obj.value)
        assert_equal(data.shift, rev)
      end
    end
  end

  describe "encryption" do
    it "checks for encryption based on the existence of the trailer's /Encrypt dictionary" do
      refute(@doc.encrypted?)
      @doc.trailer[:Encrypt] = {Filter: :Standard}
      assert(@doc.encrypted?)
    end

    it "can set or delete a security handler via #encrypt" do
      @doc.encrypt
      refute_nil(@doc.security_handler)
      assert(@doc.encrypted?)

      @doc.encrypt(name: nil)
      assert_nil(@doc.security_handler)
      refute(@doc.encrypted?)
    end

    it "doesn't decrypt the document if document.auto_encrypt=false" do
      test_file = File.join(TEST_DATA_DIR, 'standard-security-handler', 'nopwd-arc4-40bit-V1.pdf')
      doc = HexaPDF::Document.new(io: StringIO.new(File.read(test_file)),
                                  config: {'document.auto_decrypt' => false})
      assert_kind_of(String, doc.trailer[:Info][:ModDate])
      handler = HexaPDF::Encryption::SecurityHandler.set_up_decryption(doc)
      assert_kind_of(Time, handler.decrypt(doc.trailer[:Info])[:ModDate])
    end
  end

  describe "validate" do
    before do
      @doc.validate # to create a valid document
    end

    it "validates indirect objects" do
      obj = @doc.add({Type: :Page, MediaBox: [1, 1, 1, 1], Parent: @doc.pages.root})
      refute(@doc.validate(auto_correct: false))

      called = false
      assert(@doc.validate {|_, _, o| assert_same(obj, o); called = true })
      assert(called)
    end

    it "validates the trailer object" do
      @doc.trailer[:ID] = :Symbol
      refute(@doc.validate {|_, _, obj| assert_same(@doc.trailer, obj) })
    end

    it "validates only loaded objects" do
      io = StringIO.new
      doc = HexaPDF::Document.new
      doc.pages.add.delete(:Resources)
      page = doc.pages.add
      page[:Annots] = [doc.add({Type: :Annot, Subtype: :Link, Rect: [0, 0, 1, 1], H: :Z})]
      doc.write(io, validate: false)
      doc = HexaPDF::Document.new(io: io)
      doc.pages[0] # force loading of the first page

      refute(doc.validate(auto_correct: false, only_loaded: true)) # bc of Resources
      assert(doc.validate(only_loaded: true))
      refute(doc.validate(auto_correct: false)) # bc of annot key H
    end
  end

  describe "write" do
    it "writes the document to a file" do
      begin
        file = Tempfile.new('hexapdf-write')
        file.close
        @io_doc.write(file.path)
        HexaPDF::Document.open(file.path) do |doc|
          assert_equal(200, doc.object(2).value)
        end
      ensure
        file.unlink
      end
    end

    it "writes the document to an IO object" do
      io = StringIO.new(''.b)
      @doc.write(io)
      refute(io.string.empty?)
    end

    it "writes the document incrementally" do
      io = StringIO.new
      @io_doc.write(io, incremental: true)
      assert_equal(@io.string, io.string[0, @io.string.length])
    end

    it "fails if the document is not valid" do
      @doc.trailer[:Size] = :Symbol
      assert_raises(HexaPDF::Error) { @doc.write(StringIO.new(''.b)) }
    end

    it "update the ID and the Info's ModDate field" do
      _, id1 = @doc.trailer.set_random_id

      @doc.write(StringIO.new(''.b), update_fields: false)
      assert_same(id1, @doc.trailer[:ID][1])
      refute(@doc.trailer.info.key?(:ModDate))

      @doc.write(StringIO.new(''.b))
      refute_same(id1, (id2 = @doc.trailer[:ID][1]))
      assert(@doc.trailer.info.key?(:ModDate))

      @doc.trailer.info[:Author] = 'Me'
      @doc.write(StringIO.new(''.b))
      refute_same(id2, @doc.trailer[:ID][1])
      assert(@doc.trailer.info.key?(:ModDate))
      assert(@doc.trailer.info.key?(:Author))
    end

    it "it doesn't optimize the file by default" do
      io = StringIO.new(''.b)
      @io_doc.write(io)
      doc = HexaPDF::Document.new(io: io)
      assert_equal(0, doc.each.count {|o| o.type == :ObjStm })
    end

    it "allows optimizing the file by using object streams" do
      io = StringIO.new(''.b)
      @io_doc.write(io, optimize: true)
      doc = HexaPDF::Document.new(io: io)
      assert_equal(2, doc.each.count {|o| o.type == :ObjStm })
    end
  end

  describe "version" do
    it "uses the file header version of a loaded document" do
      assert_equal('1.7', @io_doc.version)
    end

    it "uses the default version for a new document" do
      assert_equal('1.2', @doc.version)
    end

    it "uses the catalog's /Version entry if it points to a later version" do
      (@doc.trailer[:Root] ||= {})[:Version] = '1.4'
      assert_equal('1.4', @doc.version)
    end

    it "allows setting the version" do
      @doc.version = '1.4'
      assert_equal('1.4', @doc.version)
    end

    it "fails setting a version with an invalid format" do
      assert_raises(ArgumentError) { @doc.version = 'bla' }
    end
  end

  describe "task" do
    it "executes the given task with options" do
      @doc.config['task.map'][:test] = lambda do |doc, arg1:|
        assert_equal(doc, @doc)
        assert_equal(:arg1, arg1)
      end
      @doc.task(:test, arg1: :arg1)
    end

    it "executes the given task with a block" do
      @doc.config['task.map'][:test] = lambda do |doc, **, &block|
        assert_equal(doc, @doc)
        block.call('inside')
      end
      assert_equal(:done, @doc.task(:test) {|msg| assert_equal('inside', msg); :done })
    end

    it "fails if the given task is not available" do
      assert_raises(HexaPDF::Error) { @doc.task(:unknown) }
    end
  end

  describe "acro_form" do
    it "returns the main AcroForm object" do
      assert_nil(@doc.acro_form)
      @doc.catalog[:AcroForm] = 5
      assert_equal(5, @doc.acro_form)
    end

    it "create the AcroForm object if instructed" do
      assert_equal(:XXAcroForm, @doc.acro_form(create: true).type)
    end
  end

  describe "listener interface" do
    it "allows registering and dispatching messages" do
      args = []
      callable = lambda {|*a| args << [:callable, a] }
      @doc.register_listener(:something, callable)
      @doc.register_listener(:something) {|*a| args << [:block, a] }
      @doc.dispatch_message(:something, :arg)
      assert_equal([[:callable, [:arg]], [:block, [:arg]]], args)
    end
  end

  describe "caching interface" do
    it "allows setting and retrieving values" do
      assert_equal(:test, @doc.cache(:a, :b, :test) { :notused })
      assert_equal(:test, @doc.cache(:a, :b) { :other })
      assert_equal(:test, @doc.cache(:a, :b))
      assert_nil(@doc.cache(:a, :c, nil))
      assert_nil(@doc.cache(:a, :c) { :other })
      assert_nil(@doc.cache(:a, :c))
      assert(@doc.cached?(:a, :b))
      assert(@doc.cached?(:a, :c))
    end

    it "allows updating a value" do
      @doc.cache(:a, :b) { :test }
      assert_equal(:new, @doc.cache(:a, :b, update: true) { :new })
    end

    it "allows clearing cached values" do
      @doc.cache(:a, :b) { :c }
      @doc.cache(:b, :c) { :d }
      @doc.clear_cache(:a)
      refute(@doc.cached?(:a, :b))
      assert(@doc.cached?(:b, :c))
      @doc.clear_cache
      refute(@doc.cached?(:a, :c))
    end

    it "fails if no cached value exists and no block is given" do
      assert_raises(LocalJumpError) { @doc.cache(:a, :b) }
    end
  end
end
