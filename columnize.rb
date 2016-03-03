#!/usr/bin/env ruby
#

#
USAGE = <<-EOF
columnize.rb

accept tsv on stdin and build fixed-width columns (for gisting)
optionally, supply column names as a csv string to include them in the output

examples:
  $ cat file.tsv | columnize.rb
  $ pbpaste | columnize.rb | pbcopy
  $ pbpaste | columnize.rb col_name,col_name_2,col_name_3 | pbcopy
EOF

max_widths = []
lines = []
input = ''

# nonblocking read means we can tell if stdin is empty
# otherwise called the program with no input would just hang
loop do
  begin
    input += $stdin.read_nonblock(4096)
  rescue IO::EAGAINWaitReadable, EOFError
    break
  end
end

if input.size == 0
  puts USAGE
  exit
end

if ARGV[0]
  lines << ARGV[0].split(',')
end

input.split("\n").each do |line|
  lines << line.strip.split("\t")
end

# figure out the longest string in each column
lines.each do |row|
  row.each_with_index do |part, idx|
    max_widths[idx] = [part.size, max_widths[idx].to_i].max
  end
end

lines.each do |line|
  # pad each item in each line
  # to the length of the longest string in the given column
  line.each_with_index do |part, idx|
    print part.ljust(max_widths[idx]) + '  '
  end
  puts
end
