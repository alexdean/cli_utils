module JenkinsStatus
  class FeedEntry
    attr_reader :title, :url, :build_number, :squad, :project, :branch, :content, :published_at, :success

    def initialize(nokogiri_element)
      # <entry>
      #   <title>Vertical: Tools » tech-guides » master #5190 (stable)</title>
      #   <link rel="alternate" type="text/html" href="https://jenkins.ted.com/job/tools_vertical/job/tech-guides/job/master/5190/" />
      #   <id>tag:hudson.dev.java.net,2020:tools_vertical/tech-guides/master:5190</id>
      #   <published>2020-01-09T23:36:29Z</published>
      #   <updated>2020-01-09T23:36:29Z</updated>
      #   <content>Success</content>
      # </entry>

      @title = nokogiri_element.css('title').text
      @url = nokogiri_element.css('link[type="text/html"]').first['href']

      id_parts = nokogiri_element.css('id').text.split(':')
      @build_number = id_parts[3]
      @squad, @project, @branch = id_parts[2].split('/')
      @content = nokogiri_element.css('content').text
      @published_at = Time.parse(nokogiri_element.css('published').text)
      @success = @content == 'Success'
    end
  end
end
