# encoding: utf-8
require 'net/telnet'
require 'date'
require 'logger'

if ARGV.size != 3 then
  print("ruby crawler.rb [usr] [pwd] [board]\n")
  exit(0)
end

USR               = ARGV[0]
PWD               = ARGV[1]
TARGET_BOARD      = ARGV[2] 
ACCOUNT_MSG       = 'guest.+new(?>[^:]+):(?>\s*)'
PASSWORD_MSG      = '\xB1\x4B\xBD\x58:'
PRESSKEY_CONTINUE = '\xBD\xD0\xAB\xF6\xA5\xF4\xB7\x4E\xC1\xE4\xC4\x7E\xC4\xF2'
ANSI_DISP_ATTR    = '\e\[(?>(?>(?>\d+;)*\d+)?)' 
ANSI_CURSOR       = '\e\[(?>(?>\d+;\d+)?)H'

# [caller]
CALLER            = '\[\xA9\x49\xA5\x73\xBE\xB9\]'

# logger
PTT_LOG = Logger.new(STDOUT)
PTT_LOG.level = Logger::DEBUG

ptt = Net::Telnet::new('Host'     => 'ptt.cc',
                       'Port'     => 23,
                       'Timeout'  => 3,
                       'Waittime' => 1)

ptt.waitfor(/#{ACCOUNT_MSG}#{ANSI_DISP_ATTR}.*(?>\b+)$/n) do |s|
  PTT_LOG.debug(s)
end

# login
ptt.cmd('String' => " " + USR, 
        'Match'  => /#{PASSWORD_MSG}/n) do |s|
  PTT_LOG.debug(s)
end

# password
ptt.cmd('String' => PWD,
        'Match'  => /#{PRESSKEY_CONTINUE}/n) do |s|
  PTT_LOG.debug(s)
end

# enter
ptt.print("\n")

# home page
ptt.waitfor(/#{CALLER}/n) do |s| 
  PTT_LOG.debug(s)
end

# search form
ptt.print("s")
ptt.waitfor(/\):(?>\s*)#{ANSI_DISP_ATTR}.*#{ANSI_CURSOR}/n) do |s| 
  PTT_LOG.debug(s)
end

# (b)in board
ARTICLES_LIST = '\xb6\x69\xaa\x4f\xb5\x65\xad\xb1'
line = ptt.cmd('String' => TARGET_BOARD, 
               'Match'  => /(?>#{PRESSKEY_CONTINUE}|#{ARTICLES_LIST})/n) do |s|
  PTT_LOG.debug(s) 
end 

begin
  if /#{PRESSKEY_CONTINUE}/n =~ line
    ptt.print('\n')
    line = ptt.waitfor(/#{ARTICLES_LIST}/n) do |s|
    end
  end
rescue Net::ReadTimeout
  retry
end

# parsing article
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

def authors_and_articles(s)
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

def page_up(ptt)
  ptt.print('P')
  ptt.waitfor(/#{ANSI_CURSOR}/n) do |s|
    print s
  end
  ptt.print('b')
  ptt.waitfor(/#{PRESSKEY_CONTINUE}/n) do |s|
    print s
  end
  begin
    ptt.print('r')
    ptt.waitfor(/#{ARTICLES_LIST}/n) do |s|
      PTT_LOG.debug(s)
    end
  rescue Net::ReadTimeout
    retry
  end
end

page_info = []
begin
  loop do
    line = gusb_ansi_by_space(line)
    info = authors_and_articles(line)
    if false == info.any? {|num, date, author| Date.today === Date.parse(date)}
      raise StopIteration
    end
    info.sort! { |x,y| y[0].to_i <=> x[0].to_i }
    info.each do |num, date, author|
      if Date.today === Date.parse(date)
        page_info.push([num, date, author])
      end
    end
    line = page_up(ptt)
  end
ensure
  PTT_LOG.debug page_info 
end
