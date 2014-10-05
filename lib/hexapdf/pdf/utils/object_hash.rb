# -*- encoding: utf-8 -*-

module HexaPDF
  module PDF
    module Utils

      # There are some structures in a PDF file, for example cross reference tables, that index data
      # based on object and generation numbers. However, there is a restriction that in such
      # structures the object numbers must be unique, e.g. there may not be entries for [1, 0] and
      # [1, 1] at the same time.
      #
      # This class can be used for storing/retrieving data for such structures.
      class ObjectHash

        include Enumerable

        # Create a new object hash.
        def initialize
          @table = {}
          @oids = {}
        end

        # :call-seq:
        #   objhash[oid, gen] = data
        #
        # Set the data for the given object and generation numbers.
        #
        # If there is already an entry for the given object number (even if the generation number is
        # different), this entry will be removed.
        def []=(oid, gen, data)
          delete(oid) if entry?(oid)
          @table[[oid, gen]] = data
          @oids[oid] = gen
        end

        # :call-seq:
        #   objhash[oid]        -> data or nil
        #   objhash[oid, gen]   -> data or nil
        #
        # Return the data for the given object number, or for the given object and generation
        # numbers.
        #
        # If there is no such data, +nil+ is returned.
        def [](oid, gen = nil)
          @table[[oid, gen || gen_for_oid(oid)]]
        end

        # :call-seq:
        #   objhash.gen_for_oid(oid)    -> Integer or nil
        #
        # Return the generation number that is stored along the given object number, or +nil+ if the
        # object number is not used.
        def gen_for_oid(oid)
          @oids[oid]
        end

        # :call-seq:
        #   objhash.entry?(oid)        -> true or false
        #   objhash.entry?(oid, gen)   -> true or false
        #
        # Return +true+ if the table has an entry for the given object number, or for the given
        # object and generation numbers.
        def entry?(oid, gen = nil)
          (gen ? gen_for_oid(oid) == gen : @oids.key?(oid))
        end

        # Delete the entry for the given object number.
        def delete(oid)
          @table.delete([oid, gen_for_oid(oid)])
          @oids.delete(oid)
        end

        # :call-seq:
        #   objhash.each {|(oid, gen), data| block }   -> objhash
        #   objhash.each                               -> Enumerator
        #
        # Call the given block once for every entry, passing an array consisting of the object and
        # generation number and the associated data as parameters.
        def each(&block)
          @table.each(&block)
        end

      end

    end
  end
end
