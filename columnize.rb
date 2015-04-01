# accept tsv on stdin and build fixed-width columns (for gisting)
#
# Usage examples:
#
#   $ cat file.tsv | ruby columnize.rb
#   $ pbpaste | ruby columnize.rb
#

max_widths = []
line_parts = []

$stdin.each do |line|
  parts = line.strip.split("\t")
  line_parts << parts
  # figure out the longest string in each column
  parts.each_with_index do |part, idx|
    max_widths[idx] = [part.size, max_widths[idx].to_i].max
  end
end

line_parts.each do |line|
  # pad each item to the length of the
  # longest string in the given column
  line.each_with_index do |part, idx|
    print part.ljust(max_widths[idx]) + '  '
  end
  puts
end
