# -*- encoding: utf-8 -*-
#
#--
# This file is part of HexaPDF.
#
# HexaPDF - A Versatile PDF Creation and Manipulation Library For Ruby
# Copyright (C) 2014-2017 Thomas Leitner
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
#++

module HexaPDF
  module Utils

    # This module is intended to be used to extend class objects. It provides the method #bit_field
    # for declaring a bit field.
    module BitField

      # Creates a bit field for managing the integer attribute +name+.
      #
      # The +mapping+ argument specifies the mapping of names to bit indices which allows one to use
      # either the bit name or its index when getting or setting. When using an unknown bit name or
      # bit index, an error is raised.
      #
      # The calling class needs to respond to \#name and \#name= because these methods are used to
      # get and set the raw integer value.
      #
      # After invoking the method the calling class has three new instance methods:
      #
      # * NAME_values which returns an array of bit names representing the set bits.
      # * NAME_include?(bit) which returns true if the given bit is set.
      # * set_NAME(*bits, clear_existing: false) for setting the given bits.
      #
      # The method names can be overridden using the arguments +lister+, +getter+ and +setter+.
      def bit_field(name, mapping, lister: "#{name}_values", getter: "#{name}_include?",
                    setter: "set_#{name}")
        bit_names = mapping.keys
        mapping.default_proc = proc do |h, k|
          if h.value?(k)
            h[k] = k
          else
            raise ArgumentError, "Invalid bit field name or index '#{k}' for #{self.name}##{name}"
          end
        end
        value_getter = name
        value_setter = "#{name}="

        define_method(lister) do
          bit_names.map {|n| send(getter, n) ? n : nil}.compact
        end
        define_method(getter) do |bit|
          (send(value_getter) || 0)[mapping[bit]] == 1
        end
        define_method(setter) do |*bits, clear_existing: false|
          send(value_setter, 0) if clear_existing || send(value_getter).nil?
          result = send(value_getter)
          bits.each {|bit| result |= 1 << mapping[bit]}
          send(value_setter, result)
        end
      end

    end

  end
end
