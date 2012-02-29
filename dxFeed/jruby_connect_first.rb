require 'qd-qds-3.102\lib\qds.jar'

include Java

import java.util.concurrent.Executors
import java.util.Arrays

import com.dxfeed.api.DXEndpoint
import com.dxfeed.api.DXFeedSubscription
import com.dxfeed.event.market.MarketEvent
import com.dxfeed.event.market.TimeAndSale
import com.dxfeed.event.market.Trade
import com.dxfeed.event.market.Summary
import com.dxfeed.api.DXFeedEventListener

import java.text.Format
import java.text.SimpleDateFormat
import java.util.Date

class Time
  @@dateFormat = SimpleDateFormat.new "yyyy-MM-dd HH:mm:ss Z"

  def self.now
    @@dateFormat.format Date.new
  end

  def self.at timestamp
    @@dateFormat.format Date.new timestamp
  end
end

class Trade
  def to_row
    ["%25s"  % Time.now,
     "%12s"  % getEventSymbol,
     "%25s"  % Time.at(getTime),
     "%4s"   % (getExchangeCode > 0 ? getExchangeCode.chr : '\0'),
     "%10s"  % getPrice,
     "%10s"  % getSize,
     "%10s"  % getDayVolume
    ].join(' ')
  end
end

class Summary
  def to_row
    ["%25s"  % Time.now,
     "%12s"  % getEventSymbol,
     "%5s"   % getDayId,
     "%10s"  % getDayOpenPrice,
     "%10s"  % getDayHighPrice,
     "%10s"  % getDayLowPrice,
     "%10s"  % getDayClosePrice,
     "%5s"   % getPrevDayId,
     "%10s"  % getPrevDayClosePrice,
     "%15s"  % getOpenInterest
    ].join(' ')
  end
end

class TimeAndSale
  def to_row
    ["%25s"  % Time.now,
     "%12s"  % getEventSymbol,
     "%25s"  % Time.at(getTime),
     "%8s"   % getSequence,
     "%4s"   % (getExchangeCode > 0 ? getExchangeCode.chr : '\0'),
     "%10s"  % getPrice,
     "%10s"  % getSize,
     "'%5s'" % getExchangeSaleConditions,
     eval("if isCancel then \"%7s\" % 'Cancel' elsif isCorrection then \"%7s\" % 'Corr' elsif isValidTick then \"%7s\" % 'Valid' elsif isNew then \"%7s\" % 'New' else \"%7s\" % 'n/a' end")
    ].join(' ')
  end
end

class File
  def print_title
    case self.path
      when /tns$/
	print ["%25s"  % 'current time',
	       "%12s"  % 'symbol',
	       "%25s"  % 'event time',
	       "%8s"   % 'sequence',
	       "%4s"   % 'exch',
	       "%10s"  % 'price',
	       "%10s"  % 'size',
	       "'%5s'" % 'cond',
	       "%7s"   % 'type'
	      ].join(' '),
	      "\n"
      when /t$/
	print ["%25s"  % 'current time',
	       "%12s"  % 'symbol',
	       "%25s"  % 'event time',
	       "%4s"   % 'exch',
	       "%10s"  % 'price',
	       "%10s"  % 'size',
	       "%10s"  % 'Volume'
	      ].join(' '),
	      "\n"
      when /s$/
	print ["%25s"  % 'current time',
	       "%12s"  % 'symbol',
	       "%5s"   % 'DayId',
	       "%10s"  % 'Open',
	       "%10s"  % 'High',
	       "%10s"  % 'Low',
	       "%10s"  % 'Close',
	       "%5s"   % 'PrevDayId',
	       "%10s"  % 'PrevClose',
	       "%15s"  % 'OpenInterest'
	      ].join(' '),
	      "\n"
    end
  end
end

class Listener
  include DXFeedEventListener

  def initialize(*files)
    super
    files.each do |file|
      case file.path
	when /_tns$/
	  @tns_file = file
	when /_t$/
	  @t_file = file
	when /_s$/
	  @s_file = file
      end
    end
  end

  def eventsReceived(events)
    @tns_arr, @t_arr, @s_arr = [], [], []

    events.each do |event|
      file = case event
	when TimeAndSale
	  @tns_arr << event.to_row
	  puts event.to_row unless event.isValidTick or event.isNew
	when Trade
	  @t_arr << event.to_row
	when Summary
	  @s_arr << event.to_row
      end
    end

    @tns_file.puts @tns_arr
    @t_file.puts @t_arr
    @s_file.puts @s_arr
end
end

feeds = {ctcq:   'caligula.mdd.lo:7130', 
	 nasdaq: 'caligula.mdd.lo:7140', 
	 otcbb:  'caligula.mdd.lo:7180',
	 opra:   'tiberius.mdd.lo:7100',
	 ice:    'caligula.mdd.lo:7150'}

events = {tns: 'TimeAndSale', t: 'Trade', s: 'Summary'}

symbols = {ctcq: %w[SPY BAC VXX TZA AZN TVIX CHK BP IWM GE],
	   nasdaq: %w[AAPL ZNGA BIDU NFLX CHTP IPSU JASO STX REGN INTC],
	   otcbb: %w[NSRS AAMRQ ACTC ECIT STEV ATTD EKDKQ CBIS RHHBY NSRGY],
	   opra: %w[DJX UKX AUX BPX GYY BUB NZD EUU BUE IVF],
	   ice: %w[/SBH2 /TFH2 /SBK2 /DXH2 /CCK2 /SBH2-/SBK2 /CCH2 /SBN2 /CCH2-/CCK2 /SBV2]}

feeds.each_key do |feed|
  eval "@#{feed}_feed = DXEndpoint.create().connect(\"#{feeds[feed]}\").getFeed()"
  
  events.each_value do |event|
    eval "@#{feed}_sub ||= [#{event}.java_class]"
    eval "@#{feed}_sub += [#{event}.java_class]"
  end
  eval "@#{feed}_sub = @#{feed}_feed.createSubscription *@#{feed}_sub"

  events.each_key do |suffix|
    eval "@#{feed}_#{suffix} = File.open \"cancorrs_#{feed}_#{suffix}\", \"w\""
    eval "@#{feed}_#{suffix}.print_title"
  end

  eval "@#{feed}_sub.addEventListener Listener.new(@#{feed}_#{events.keys[0]},
						  @#{feed}_#{events.keys[1]},
						  @#{feed}_#{events.keys[2]})"

  eval "@#{feed}_sub.addSymbols Arrays.asList(*#{symbols[feed]})"
end


begin
  loop do
    sleep 1
    feeds.each_key do |feed|
      events.each_key do |suffix|
	eval "@#{feed}_#{suffix}.fsync"
      end
    end
  end
ensure
  feeds.each_key do |feed|
    events.each_key do |suffix|
      eval "@#{feed}_#{suffix}.close"
    end
  end
end
