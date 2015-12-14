require "pttcrawler/version"
require "net/telnet"
require "logger"
require "date"

module Pttcrawler

  PTT_HOST          = 'ptt.cc' 

  # some keyword to detect recv server data finish.
  ACCOUNT_MSG       = 'guest.+new(?>[^:]+):(?>\s*)'
  PASSWORD_MSG      = '\xB1\x4B\xBD\x58:'
  PRESSKEY_CONTINUE = '\xBD\xD0\xAB\xF6\xA5\xF4\xB7\x4E\xC1\xE4\xC4\x7E\xC4\xF2'
  ANSI_DISP_ATTR    = '\e\[(?>(?>(?>\d+;)*\d+)?)' 
  ANSI_CURSOR       = '\e\[(?>(?>\d+;\d+)?)H'
  CALLER            = '\[\xA9\x49\xA5\x73\xBE\xB9\]'
  ARTICLES_LIST     = '\xb6\x69\xaa\x4f\xb5\x65\xad\xb1'

  # debug level
  PTT_DEBUG = Logger::DEBUG 
  PTT_INFO  = Logger::INFO
  PTT_WARN  = Logger::WARN
  PTT_ERROR = Logger::ERROR
  PTT_FATAL = Logger::FATAL

  class Crawler
    # crawling ptt article
    #
    # Example:
    #   >> c = Crawler.new()
    #
    # Arguments
    #   usr: ptt account
    #   pwd: ptt password

    def initialize(port:23, timeout:3, waittime:1, log_level:PTT_DEBUG)
      @ptt = Net::Telnet.new('Host'     => PTT_HOST, 
                             'Port'     => port,
                             'Timeout'  => timeout,
                             'Waittime' => waittime)
      @log_level  = log_level
      @ptt_logger = Logger.new(STDOUT)
      @ptt_logger.formatter = proc do |severity, datetime, progname, msg|
        "#{msg}"
      end   
    end

  public

    def login(usr, pwd)
      # step1: connect to server
      @ptt.waitfor(/#{ACCOUNT_MSG}#{ANSI_DISP_ATTR}.*(?>\b+)$/n) do |s|
        @ptt_logger.debug(s)
      end
      # step2: send user account
      @ptt.cmd('String' => " " + usr, 
              'Match'   => /#{PASSWORD_MSG}/n) do |s|
        @ptt_logger.debug(s)
      end
      # step3: send password
      @ptt.cmd('String' => pwd, 
               'Match'  => /#{PRESSKEY_CONTINUE}/n) do |s|
        @ptt_logger.debug(s) 
      end
      # step4: home page
      # FIXME: currently, no check double login
      @ptt.print("\n")
      @ptt.waitfor(/#{CALLER}/n) do |s| 
        @ptt_logger.debug(s)
      end
      yield
    end

    def get_today_article_list(board)
      line = checkin(board)
      article_list = []
      begin
        loop do
          line = gusb_ansi_by_space(line)
          info = get_authors_and_articles(line)
          if false == info.any? {|num, date, author| Date.today === Date.parse(date)}
            raise StopIteration
          end
          info.sort! { |x,y| y[0].to_i <=> x[0].to_i }
          info.each do |num, date, author|
            if Date.today === Date.parse(date)
              article_list.push([num, date, author])
            end
          end
          line = article_list_page_up
        end
      ensure
        @ptt_logger.debug article_list 
      end
    end

  private

    def checkin(board)
      # step1: search board
      @ptt.print("s")
      @ptt.waitfor(/\):(?>\s*)#{ANSI_DISP_ATTR}.*#{ANSI_CURSOR}/n) do |s| 
        @ptt_logger.debug(s)
      end
      # step2: get entrance board string
      line = @ptt.cmd('String' => board, 
                      'Match'  => /(?>#{PRESSKEY_CONTINUE}|#{ARTICLES_LIST})/n) do |s|
        @ptt_logger.debug(s) 
      end 
      # check get articles list
      begin
        if /#{PRESSKEY_CONTINUE}/n =~ line
          @ptt.print('\n')
          line = @ptt.waitfor(/#{ARTICLES_LIST}/n) do |s|
            @ptt_logger.debug(s)
          end
        end
      rescue Net::ReadTimeout
        retry
      end
      return line
    end

    def gusb_ansi_by_space(s)
      raise ArgumentError unless s.kind_of? String
      s.gsub!(/#{ANSI_DISP_ATTR}m|#{ANSI_CURSOR}|\e\[K/) do |m|
        if m[m.size - 1] == 'K'
          "\n"
        else
          " "
        end
      end
    end

    def get_authors_and_articles(s)
      raise ArgumentError unless s.kind_of? String
      info_list = []
      s.scan(/\s(\d+)(?>\s+)
             (?>(?:[~+mMsS!](?=\s))?)
             (?>(?>\s*(?>\xC3\x7A|XX|X\d|\d+)(?=\s))?)
             (?>\s*)(\d+\/\d+)(?>\s+)
             (?>\s*)(?!(?>\d+\s))(\w{2,})\s+
             /nx) do |num, date, author|
        info_list.push([num, date, author])
      end
      info_list
    end

    def article_list_page_up
      @ptt.print('P')
      @ptt.waitfor(/#{ANSI_CURSOR}/n) do |s|
        @ptt_logger.debug(s)
      end
      @ptt.print('b')
      @ptt.waitfor(/#{PRESSKEY_CONTINUE}/n) do |s|
        @ptt_logger.debug(s)
      end
      begin
        @ptt.print('r')
        @ptt.waitfor(/#{ARTICLES_LIST}/n) do |s|
          @ptt_logger.debug(s)
        end
      rescue Net::ReadTimeout
        retry
      end
    end

  end
end
