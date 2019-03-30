require "logger"
require "strscan"
require "byebug"

class SqlFormatter
  # Config = Struct.new(:indent_level, :append_newline, :prepend_newline, :is_section)
  Token = Struct.new(:content, :is_keyword, :is_last, :sub_start, :sub_end, :is_section)

  attr_reader :log

  def self.sections
    [
      "SELECT",
      "FROM",
      "WHERE",
      "GROUP BY",
      "ORDER BY",
      "LIMIT",
      "OFFSET"
    ]
  end

  def self.other_tokens
    [
      "((INNER|OUTER|LEFT)? ?JOIN)",
      '\(',
      '\)',
      '(?<= )AND(?= )',
      '(?<= )OR(?= )',
      # ','
    ]
  end

  def self.keywords
    sections + other_tokens
  end

  def initialize(logger: nil)
    @log = logger || Logger.new("/dev/null")
  end

  def tokenize(input)
    regex = Regexp.new(self.class.keywords.join("|"), Regexp::IGNORECASE)
    s = StringScanner.new(input.strip)

    tokens = []
    parenthesis_depth = 0
    subquery_at = [] #parenthesis depths which are subqueries
    while !s.eos?
      hunk = s.scan_until(regex)

      if !hunk
        hunk = s.scan_until(/$/)
        # TODO not setting is_section correctly for these.
        tokens << Token.new(hunk, false, true)
        next
      end

      matched_keyword = s.values_at(0)[0]
      if matched_keyword != hunk
        # keyword is always at the end of the hunk, because #scan_until
        without_keyword = hunk[0..(matched_keyword.size * -1 - 1)]
        tokens << Token.new(without_keyword, false)
      end

      is_section = self.class.sections.include?(matched_keyword)

      sub_start = false
      sub_end = false
      if matched_keyword == "("
        parenthesis_depth += 1

        if s.post_match.match(/^\s*SELECT/i)
          subquery_at << parenthesis_depth
          sub_start = true
        end
      elsif matched_keyword == ")"
        if subquery_at.last == parenthesis_depth
          sub_end = true
          subquery_at.pop
        end

        parenthesis_depth -= 1
      end

      tokens << Token.new(matched_keyword, true, false, sub_start, sub_end, is_section)
    end

    tokens
  end

  def format(input, indent_size: 2, indent_level: 0)
    default_format(tokenize(input),
      indent_size: indent_size,
      indent_level: indent_level
    )
  end

  # in order to get
  #   AND (a = 1 OR b = 2)
  #   OR (c = 3 OR b = 4)
  # i need to know whether AND/OR occurs within a parenthesis or not.
  def default_format(tokens, indent_size: 2, indent_level: 0)
    output = ""
    current_section = nil
    query_indent_baselines = [0] # indent level that query keywords are indented to
    indent_level = 0 # indent to use with current hunk (includes baseline)

    tokens.each_with_index do |token, idx|
      prepend_newline = false
      append_newline = false
      hunk = nil

      log.debug {token.inspect}

      if token.is_section
        log.debug { 'is_section'}
        # all sections except first are preceeded by a newline
        prepend_newline = true unless idx == 0
        # return to current baseline
        indent_level = query_indent_baselines.last
        hunk = indent(indent_level, indent_size) + token.content
        indent_level += 1
      elsif token.sub_end
        log.debug { 'sub_end' }
        indent_level = query_indent_baselines.pop - 1
        prepend_newline = true
        hunk = indent(indent_level, indent_size) + token.content
      # all non-section keywords except '(' and ')' are preceeded by a newline
      elsif token.is_keyword && !['(', ')'].include?(token.content)
        log.debug { 'non-parenthetical keyword'}
        prepend_newline = true
        lstrip = true
        hunk = indent(indent_level, indent_size) + token.content.lstrip
      # content after a newline should be indented
      elsif output[-1] == "\n"
        log.debug { 'preceeded by newline'}
        lstrip = true
        hunk = indent(indent_level, indent_size) + token.content.lstrip
      # non-keyword content not following a newline is output as is
      else
        log.debug { 'default' }
        hunk = token.content
      end

      if token.sub_start
        log.debug { 'sub_start' }
        append_newline = true
        query_indent_baselines << indent_level + 1
      end

      # hunk = indent(indent_level, indent_size)
      # hunk += (lstrip ? token.content.lstrip : token.content)

      # all sections except FROM are followed by a newline
      if token.is_section && !['FROM', 'LIMIT', 'OFFSET'].include?(token.content)
        append_newline = true
      end

      # remove trailing whitespace from a line
      if append_newline
        hunk = hunk.rstrip
      end
      if prepend_newline
        output = output.rstrip
      end

      # do output
      if prepend_newline
        output += "\n"
      end
      output += hunk
      if append_newline
        output += "\n"
      end
    end

    output
  end

  def indent(level, size)
    ' ' * level * size
  end

  def format_1(input, tab_size: 2)
    tokens = tokenize(input)

    log.debug { tokens.inspect }

    output = ""
    parenthesis_depth = 0
    subquery_at = [] # parenthesis depths which are the begin/end of a subquery

    # indent = 0

    tokens.each_with_index do |token, idx|
      log.debug { token.inspect }

      subquery_depth = subquery_at.size
      baseline = (" " * tab_size * subquery_depth)

      if token.is_keyword
        content = token.content
        keyword_config = @@indents.detect { |(key, config)| content.upcase.match(key) }[1]
        # indent = keyword_config.indent_level
        append_newline = keyword_config.append_newline
        prepend_newline = keyword_config.prepend_newline
        sub_start = false
        sub_end = false

        next_token = tokens[idx + 1]
        if content == "("
          parenthesis_depth += 1
          if next_token.content.upcase == "SELECT"
            # start of subquery
            subquery_at << parenthesis_depth
            sub_start = true
            append_newline = true
          end
        elsif content == ")"
          if subquery_at.last == parenthesis_depth
            sub_end = true
            subquery_at.pop
            append_newline = true
          end
          parenthesis_depth -= 1
        end

        indent = ""
        if output[-1] == "\n"
          indent = baseline + (keyword_config.is_section ? "" : (" " * tab_size))
        end

        log.debug { "parenthesis_depth:#{parenthesis_depth}, subquery_depth:#{subquery_depth}, baseline:'#{baseline.size}', indent:'#{indent.size}'"}



        if prepend_newline
          output += "\n"
          # output += "\n" + (" " * (indent + 1) * tab_size)
        end


        output += indent + token.content.upcase

        if append_newline
          output += "\n" # + (" " * (indent + 1) * tab_size)
        else
          output += " "
        end
      else
        indent = ""
        if output[-1] == "\n"
          indent = baseline + (" " * tab_size)
        end
        output += indent + token.content
        # output += "\n" if !token.is_last
      end

      # keyword_config = indents[matched_keyword.upcase]
      # puts "hunk: "#{hunk}", matched_keyword: "#{matched_keyword}", without_keyword: "#{without_keyword}", keyword_config: #{keyword_config}"

      # if keyword_config
      #   indent = keyword_config.indent_level
      #   append_newline = keyword_config.append_newline

      #   if without_keyword
      #     output += without_keyword + "\n"
      #   end

      #   output += (" " * indent * tab_size) + matched_keyword.upcase

      #   if append_newline
      #     output += "\n" + (" " * (indent + 1) * tab_size)
      #   else
      #     output += " "
      #   end
      # else
      #   output += hunk
      # end

      log.debug { "output:\n*****\n#{output}\n*****\n" }

      # puts output
    end

    output
  end
end
