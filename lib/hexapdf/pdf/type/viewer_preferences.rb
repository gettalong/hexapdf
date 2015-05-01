# -*- encoding: utf-8 -*-

require 'hexapdf/pdf/dictionary'

module HexaPDF
  module PDF
    module Type

      # Represents the PDF's viewer preferences dictionary which defines how a document should be
      # presented on screen or in print.
      #
      # This dictionary is linked via the /ViewerPreferences entry from the Catalog.
      #
      # See: PDF1.7 s12.2, Catalog
      class ViewerPreferences < Dictionary

        define_field :HideToolbar,           type: Boolean, default: false
        define_field :HideMenubar,           type: Boolean, default: false
        define_field :HideWindowUI,          type: Boolean, default: false
        define_field :FitWindow,             type: Boolean, default: false
        define_field :CenterWindow,          type: Boolean, default: false
        define_field :DisplayDocTitle,       type: Boolean, default: false, version: '1.4'
        define_field :NonFullScreenPageMode, type: Symbol,  default: :UseNone
        define_field :Direction,             type: Symbol,  default: :L2R, version: '1.3'
        define_field :ViewArea,              type: Symbol,  default: :CropBox, version: '1.4'
        define_field :ViewClip,              type: Symbol,  default: :CropBox, version: '1.4'
        define_field :PrintArea,             type: Symbol,  default: :CropBox, version: '1.4'
        define_field :PrintClip,             type: Symbol,  default: :CropBox, version: '1.4'
        define_field :PrintScaling,          type: Symbol,  default: :AppDefault, version: '1.6'
        define_field :Duplex,                type: Symbol,  version: '1.7'
        define_field :PickTrayByPDFSize,     type: Boolean, version: '1.7'
        define_field :PrintPageRange,        type: Array,   version: '1.7'
        define_field :NumCopies,             type: Integer, version: '1.7'

      end

    end
  end
end
