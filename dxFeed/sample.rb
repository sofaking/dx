require 'qd-qds-3.102\lib\qds.jar'

include Java

import java.util.Arrays

import com.dxfeed.api.DXEndpoint
import com.dxfeed.api.DXFeedSubscription
import com.dxfeed.event.market.MarketEvent
import com.dxfeed.event.market.TimeAndSale
import com.dxfeed.api.DXFeedEventListener

class Time
  class << Time
    alias __at__ at
    def at *args
      if args.length == 2
	__at__(*args).strftime("%m-%d %T.%L")
      else
	__at__(*args).strftime("%m-%d %T")
      end
    end

    alias __now__ now
    def now
      __now__.strftime("%m-%d %T")
    end
  end
end

class TimeAndSale
  def to_row
    timestamp = getTime.to_s
    secs = timestamp[0..-4].to_i
    msecs = timestamp[-3..-1].to_i

    ["%13s"  % Time.now,
     "%12s"  % getEventSymbol,
     "%17s"  % Time.at(secs, msecs),
     "%8s"   % getSequence,
     "%4s"   % (getExchangeCode > 0 ? getExchangeCode.chr : '\0'),
     "%10s"  % getPrice,
     "%10s"  % getSize,
     "'%5s'" % getExchangeSaleConditions,
     eval("if isCancel then \"%7s\" % 'Cancel' elsif isCorrection then \"%7s\" % 'Corr' elsif isValidTick then \"%7s\" % 'Valid' elsif isNew then \"%7s\" % 'New' else \"%7s\" % 'n/a' end")
    ].join(' ')
  end
end

class Listener
  include DXFeedEventListener

  def eventsReceived(events)
    events.each do |event|
      file = case event
	when TimeAndSale
	  if event.isValidTick or event.isNew
	    puts event.to_row 
	  end
      end
    end
  end
end

nasdaq_symbols = %w[AAPL ZNGA BIDU NFLX CHTP IPSU JASO STX REGN INTC]
gif_symbols = %w[WITE.IV]

#feed = DXEndpoint.create().connect('caligula.mdd.lo:7140').getFeed()
feed = DXEndpoint.create().connect('caligula.mdd.lo:7136').getFeed()
feed_sub = feed.createSubscription TimeAndSale.java_class
feed_sub.addEventListener Listener.new
feed_sub.addSymbols Arrays.asList(*gif_symbols)

loop { sleep 1 }
