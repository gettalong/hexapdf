# -*- encoding: utf-8 -*-

module HexaPDF

  # Returns the data directory for HexaPDF.
  def self.data_dir
    unless defined?(@data_dir)
      require 'rbconfig'
      @data_dir = File.expand_path(File.join(__dir__, '..', '..', 'data', 'hexapdf'))
      unless File.directory?(@data_dir)
        @data_dir = File.expand_path(File.join(Config::CONFIG["datadir"], "hexapdf"))
      end
      unless File.directory?(@data_dir)
        raise "HexaPDF data directory not found! This is a bug, please report it!"
      end
    end
    @data_dir
  end

end
