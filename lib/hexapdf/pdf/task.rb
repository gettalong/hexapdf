# -*- encoding: utf-8 -*-

module HexaPDF
  module PDF

    # == Overview
    #
    # The Task module contains task implementations which are used to perform operations that affect
    # a whole PDF document instead of just a single object.
    #
    # Normally, such operations would be implemented by using methods on the Document class.
    # However, this would clutter up the document interface with various methods and also isn't very
    # extensible.
    #
    # A task name that can be used for Document#task is mapped to a task object via the 'task.map'
    # configuration option.
    #
    #
    # == Implementing a Task
    #
    # A task is simply a callable object that takes the document as first mandatory argument and can
    # optionally take keyword arguments and/or a block. This means that a block suffices.
    #
    # Here is a simple example:
    #
    #   doc = HexaPDF::PDF::Document.new
    #   doc.config['task.map'][:validate] = lambda do |doc|
    #     doc.each(current: false) {|obj| obj.validate || raise "Invalid object #{obj}"}
    #   end
    module Task

      autoload(:SetMinPDFVersion, 'hexapdf/pdf/task/set_min_pdf_version')
      autoload(:Optimize, 'hexapdf/pdf/task/optimize')
      autoload(:Dereference, 'hexapdf/pdf/task/dereference')

    end

  end
end
