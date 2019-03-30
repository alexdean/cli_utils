require "minitest/autorun"
require_relative "../lib/sql_formatter"

describe SqlFormatter do
  before do
    logger = Logger.new($stderr)
    logger.level = Logger::DEBUG
    @subject = SqlFormatter.new(logger: logger)
  end

  describe "#tokenize" do
    it "should find tokens" do
      tokens = @subject.tokenize("SELECT * FROM table WHERE basement = 1 ORDER BY roof")

      assert_equal(
        ["SELECT", " * ", "FROM", " table ", "WHERE", " basement = 1 ", "ORDER BY", " roof"],
        tokens.map(&:content)
      )
    end

    it "should identify tokens which are sections" do
      tokens = @subject.tokenize("SELECT * FROM table WHERE basement = 1 ORDER BY roof")

      assert_equal(
        [true, nil, true, nil, true, nil, true, nil],
        tokens.map(&:is_section)
      )
    end

    it "should find OR but not door" do
      tokens = @subject.tokenize('door or more')
      assert_equal(
        ['door ', 'or', ' more'],
        tokens.map(&:content)
      )
    end

    it "should find AND but not NAND or anderson" do
      tokens = @subject.tokenize('nand and anderson')
      assert_equal(
        ['nand ', 'and', ' anderson'],
        tokens.map(&:content)
      )
    end

    it "identifies subquery boundaries" do
      tokens = @subject.tokenize('SELECT (SELECT COUNT(*) FROM)')

      assert_equal "(", tokens[2].content
      assert tokens[2].sub_start

      assert_equal "(", tokens[5].content
      assert !tokens[5].sub_start

      assert_equal ")", tokens[7].content
      assert !tokens[7].sub_end

      assert_equal ")", tokens[10].content
      assert tokens[10].sub_end
    end

    it "should not strip additional whitespace between tokens"
    it "should set is_section:true on final token if needed"
  end

  describe "#format" do
    it "doesn't add extra spacing around parenthesis" do
      assert_equal('count(*)', @subject.format('count(*)'))
    end

    it "should squash newlines in the input string" # normalize all whitespace, or just newlines?

    it "should format basic sections" do
      input = "SELECT * FROM table WHERE a = 1 ORDER BY a LIMIT 5 OFFSET 10"
      expected = <<~EOF.chomp
        SELECT
          *
        FROM table
        WHERE
          a = 1
        ORDER BY
          a
        LIMIT 5
        OFFSET 10
      EOF

      actual = @subject.format(input)
      assert_equal expected, actual
    end

    it "should indent joins under FROM" do
      input = "FROM table_a AS a INNER JOIN table_b AS b ON (a.id = b.id) LEFT JOIN table_c AS c USING (id)"
      expected = <<~EOF.chomp
        FROM table_a AS a
          INNER JOIN table_b AS b ON (a.id = b.id)
          LEFT JOIN table_c AS c USING (id)
      EOF

      actual = @subject.format(input)
      assert_equal expected, actual
    end

    it "should indent WHERE clauses" do
      input = "WHERE a = 1 AND b = 2 OR c = 3 AND d = 4"
      expected = <<~EOF.chomp
        WHERE
          a = 1
          AND b = 2
          OR c = 3
          AND d = 4
      EOF

      actual = @subject.format(input)
      assert_equal expected, actual
    end

    it "should keep parenthetical logical expressions on the same line" do
      # skip

      input = "WHERE (a = 1 AND b = 2) OR (c = 3 AND d = 4)"
      expected = <<~EOF.chomp
        WHERE
          (a = 1 AND b = 2)
          OR (c = 3 AND d = 4)
      EOF

      actual = @subject.format(input)
      assert_equal expected, actual
    end

    it "should format derived tables" do
      input = "FROM table INNER JOIN (SELECT y FROM table) AS x"
      expected = <<~EOF.chomp
        FROM table
          INNER JOIN (
            SELECT
              y
            FROM table
          ) AS x
      EOF

      actual = @subject.format(input)
      assert_equal expected, actual
    end

    it "should format subselects" do
      input = "WHERE x IN (SELECT y FROM table)"
      expected = <<~EOF.chomp
        WHERE
          x IN (
            SELECT
              y
            FROM table
          )
      EOF

      actual = @subject.format(input)
      assert_equal expected, actual
    end

    it "puts sections on new lines" do
      input = "SELECT a, b, c FROM foo INNER JOIN blork ON (a = q) LEFT JOIN ( SELECT a FROM b WHERE c = d) as q WHERE bbq=1 AND kale IS NOT NULL AND id IN (SELECT a FROM q WHERE x IN (SELECT x FROM y)) ORDER BY calories GROUP BY foo, var"
      expected = <<~EOF
        SELECT
          a, b, c
        FROM foo
          INNER JOIN blork ON (a = q)
          LEFT JOIN (
            SELECT
              a
            FROM b
            WHERE
              c = d
          ) as q
        WHERE
          bbq=1
          AND kale IS NOT NULL
          AND id IN (
            SELECT
              a
            FROM q
            WHERE
              x IN (
                SELECT
                  x
                FROM y
              )
          )
        ORDER BY
          calories
        GROUP BY
          foo, var
      EOF

      actual = @subject.format(input)
      assert_equal expected.strip, actual
    end
  end
end
