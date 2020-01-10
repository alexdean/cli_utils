require_relative './feed_entry'

module JenkinsStatus
  class Feed
    # @param [String] feed Unparsed XML document. A jenkins RSS feed.
    def initialize(feed)
      @entries = []

      doc = Nokogiri::XML(feed)
      doc.css('feed entry').each do |element|
        @entries << FeedEntry.new(element)
      end
    end

    def report
      rows = []
      @entries.each do |entry|
        rows << [entry.content, entry.project, entry.branch, entry.build_number, entry.published_at.iso8601]
      end

      rows.sort_by! { |i| i[1] }

      Terminal::Table.new(headings: header_row, rows: rows)
    end

    def header_row
      ['Status', 'Project', 'Branch', 'Build', 'Date']
    end
  end
end
