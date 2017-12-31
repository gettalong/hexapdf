require 'combine_pdf'

CombinePDF.load(ARGV.shift).save(ARGV.shift)
