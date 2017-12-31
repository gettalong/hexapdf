require 'origami'
Origami::OPTIONS[:enable_type_propagation] = false
pdf = Origami::PDF.read(ARGV.shift, {logger: STDOUT})
pdf.save(ARGV.shift, :noindent => true, :use_xrefstm => true, :use_xreftable => false, :obfuscate => false)
