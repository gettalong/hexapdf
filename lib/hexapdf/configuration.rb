# -*- encoding: utf-8 -*-

require 'yaml'
require 'hexapdf/error'

module HexaPDF

  # Contains the available configuration options for a HexaPDF document.
  #
  # == Overview
  #
  # HexaPDF allows detailed control over all aspects of PDF manipulation. If there is a need to use
  # a certain default value somewhere, it is defined as configuration options so that it can easily
  # be changed later.
  #
  # A configuration option name is dot-separted to provide a hierarchy of option names. For example,
  # hexapdf.stream.chunk_size.
  #
  # Although configuration options are globally defined, each HexaPDF document gets its own
  # configuration object to allow changing of the default values.
  #
  # Note that this is just a convenience object! Using a simple Hash is also possible since the only
  # methods used on the configuration object are #[] and #[]=.
  #
  #
  # == Usage
  #
  # Configuration options can be defined by using the ::define method:
  #
  #   Configuration.define "my.new.option", 'default value', 'A description'
  #
  # and later accessed or set on the object using the accessor methods #[] and #[]=. A validation
  # block can also be specified when defining an option. This validation block is called when a new
  # value should be set and it should return the (possibly changed) value to be set:
  #
  #   Configuration.define "my.new.option", 'default value' do |val|
  #     raise "Option must be a string" unless val.kind_of?(String)
  #     val.upcase
  #   end
  #
  class Configuration

    # Raised by the HexaPDF::Configuration class if there are any problems.
    class Error < HexaPDF::Error; end

    # Struct class for storing the data of a configuration option.
    Option = Struct.new(:default, :description, :validator)

    @options = {}

    # Define a new option +name+ with a default value of +default+ and an optional +description+.
    #
    # If a validation block is provided, it is called with the new value when one is set and should
    # return a (possibly altered) value to be set.
    def self.define(name, default, description = '', &validator)
      if @options.has_key?(name)
        raise Error, "Configuration option '#{name}' has already be defined"
      else
        @options[name] = Option.new
        @options[name].default = default.freeze
        @options[name].description = description.freeze
        @options[name].validator = validator.freeze
        @options[name].freeze
      end
    end

    # Return all the defined configuration options.
    def self.options
      @options
    end


    # Create a new Configuration object.
    def initialize
      @values = {}
    end

    # Return +true+ if the given option exists.
    def option?(name)
      self.class.options.has_key?(name)
    end

    # Return the value for the configuration option +name+.
    #
    # Raises an error if the given configuration option name doesn't exist.
    def [](name)
      if self.class.options.has_key?(name)
        @values.fetch(name, self.class.options[name].default)
      else
        raise Error, "Configuration option '#{name}' does not exist"
      end
    end

    # Use +value+ as the value for the configuration option +name+.
    def []=(name, value)
      if self.class.options.has_key?(name)
        begin
          @values[name] = (self.class.options[name].validator ? self.class.options[name].validator.call(value) : value)
        rescue
          raise Error, "Problem setting configuration option '#{name}': #{$!.message}", $!.backtrace
        end
      else
        raise Error, "Configuration option '#{name}' does not exist"
      end
    end

    # Set the configuration values from the Hash +values+.
    #
    # The hash can either contain full configuration option names or namespaced option names, ie. in
    # YAML format:
    #
    #   my.option: value
    #
    #   hexapdf:
    #     stream.chunksize: 10
    #     something: here
    #
    # The above hash will set the option 'my.option' to 'value', 'hexapdf.stream.chunksize' to '10'
    # and 'hexapdf.something' to 'here'.
    #
    # Returns an array with all unknown configuration options.
    def set_values(values)
      unknown_options = []
      process = proc do |name, value|
        if self.class.options.has_key?(name)
          self[name] = value
        elsif value.kind_of?(Hash)
          value.each {|k,v| process.call("#{name}.#{k}", v)}
        else
          unknown_options << name
        end
      end
      values.each(&process)
      unknown_options
    end

  end

end
