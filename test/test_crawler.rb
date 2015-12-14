require 'test/unit'
require 'pttcrawler'

class PttcrawlerTest < Test::Unit::TestCase 
  def test_gossiping_crawling
    usr = ENV['PTT_USR']
    pwd = ENV['PTT_PWD']
    board = 'Gossiping'
    crawler = Pttcrawler::Crawler.new
    crawler.login usr, pwd do
      crawler.get_today_article_list(board)
    end
  end
end
