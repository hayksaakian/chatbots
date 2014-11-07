require 'rubygems'
require 'net/http'
require 'open-uri'
require 'json'
require 'cgi'
require 'digest'
require 'action_view'
require 'similar_text'
include ActionView::Helpers::DateHelper

class RandomAslan
  VALID_WORDS = %w{randomaslan}
  RATE_LIMIT = 22 # seconds
  PICTURES = [
"i.imgur.com/7CKen57.png",
"i.imgur.com/qTfcv6z.jpg",
"i.imgur.com/jr5tN1Z.jpg",
"i.imgur.com/nwsnucQ.jpg",
"i.imgur.com/esgubkS.jpg",
"i.imgur.com/0fhs9Hn.png",
"i.imgur.com/Gm2ZZHW.jpg",
"i.imgur.com/LUUFZSi.jpg",
"i.imgur.com/KZ0INJo.jpg",
"i.imgur.com/kIMVlYR.jpg",
"i.imgur.com/ovCFSmc.jpg",
"i.imgur.com/7EJWRLS.jpg",
"i.imgur.com/btHzG6k.jpg",
"i.imgur.com/QodDNpD.jpg",
"i.imgur.com/aC4FM2d.jpg",
"i.imgur.com/G4jATsN.jpg",
"i.imgur.com/vXqSR1S.jpg",
"i.imgur.com/4LP72lu.jpg",
"i.imgur.com/9qDdnwR.jpg",
"i.imgur.com/BUSdLT1.jpg",
"i.imgur.com/otKft3L.jpg",
"i.imgur.com/QfVdLQN.jpg",
"i.imgur.com/aeMsfbO.jpg",
"i.imgur.com/VE5vMzp.jpg",
"i.imgur.com/kYQ2DDB.jpg",
"i.imgur.com/m10IMxd.jpg",
"i.imgur.com/YrwA2Ky.jpg",
"i.imgur.com/zX1rwI4.jpg",
"i.imgur.com/fuWZ6P6.jpg",
"i.imgur.com/oCQrpUE.jpg",
"i.imgur.com/wqbdZYD.jpg",
"i.imgur.com/iYHw5Yu.jpg",
"i.imgur.com/MXfZXTC.jpg",
"i.imgur.com/XgeYHxU.jpg",
"i.imgur.com/l5845Fb.jpg",
"i.imgur.com/wJc1ACo.jpg",
"i.imgur.com/XjtAer0.jpg",
"i.imgur.com/9gIywT9.jpg",
"i.imgur.com/IUyi5za.jpg",
"i.imgur.com/BbCUuNl.jpg",
"i.imgur.com/kkESxWN.jpg",
"i.imgur.com/cyj4tUn.jpg",
"i.imgur.com/tIVg5Kv.jpg",
"i.imgur.com/UvsL62m.jpg",
"i.imgur.com/a40LqZn.jpg",
"i.imgur.com/PPG9wBk.jpg",
"i.imgur.com/ZHcPU5i.jpg",
"i.imgur.com/I7d4jrW.jpg",
"i.imgur.com/LYdvJcL.jpg",
"i.imgur.com/yU4xEVl.jpg",
"i.imgur.com/CNRihXs.jpg",
"i.imgur.com/I6EZH5i.jpg",
"i.imgur.com/2XdS7PI.jpg",
"i.imgur.com/gWh7v08.jpg",
"i.imgur.com/wjvAAPY.jpg",
"i.imgur.com/y5gwYpS.jpg",
"i.imgur.com/tA6aLnc.jpg",
"i.imgur.com/TTZrfuz.gif",
"i.imgur.com/5KMRbyX.gif",
"i.imgur.com/hwYIXXl.gif",
"i.imgur.com/JkrNV.jpg",
"i.imgur.com/qMfMl.gif",
"i.imgur.com/vm46R.gif",
"i.imgur.com/UsG8C.jpg",
"i.imgur.com/pOh7M.jpg",
"i.imgur.com/t4wez.jpg",
"i.imgur.com/xDMSO.jpg",
"i.imgur.com/rZpTf.jpg",
"i.imgur.com/IlA6i.jpg",
"i.imgur.com/swjct.jpg",
"i.imgur.com/1p6Qh.jpg",
"i.imgur.com/h9yfb.jpg",
"i.imgur.com/bskqb.jpg",
"i.imgur.com/6unYj.jpg",
"i.imgur.com/f46CY.jpg",
"i.imgur.com/xszgf.jpg",
"i.imgur.com/qUMa4.jpg",
"i.imgur.com/Z8eku.png",
"i.imgur.com/oA0RU.png",
"i.imgur.com/s1rbI.png",
"i.imgur.com/YIVhC.png",
"i.imgur.com/iXeO1.png",
"i.imgur.com/DCQsH.jpg",
"i.imgur.com/ufdPy.jpg",
"i.imgur.com/M59kL.jpg",
"i.imgur.com/5v9bm.jpg",
"i.imgur.com/K8FMP.png",
"i.imgur.com/aa71R.jpg",
"i.imgur.com/nvKTt.jpg",
"i.imgur.com/GDCgO.jpg",
"i.imgur.com/JKWO9.jpg",
"i.imgur.com/D25UK.jpg",
"i.imgur.com/J02ko.jpg",
"i.imgur.com/XB8Cx.jpg",
"i.imgur.com/liRmn.jpg",
"i.imgur.com/EutQH.jpg",
"i.imgur.com/gCr2M.jpg",
"i.imgur.com/c0BeE.jpg",
"i.imgur.com/yHUyD.jpg",
"i.imgur.com/njODR.jpg",
"i.imgur.com/Dl4BV.jpg",
"i.imgur.com/Bxgh4.jpg",
"i.imgur.com/bcjqd.jpg",
"i.imgur.com/HcbVW.jpg",
"i.imgur.com/a0vIz.jpg",
"i.imgur.com/FVANc.jpg",
"i.imgur.com/V4NUN.png",
"i.imgur.com/dBqxt.jpg",
"i.imgur.com/abd7q.jpg",
"i.imgur.com/j3LTf.png",
"i.imgur.com/y0A2U.jpg",
"i.imgur.com/X5Qol.png",
"i.imgur.com/B9BrE.png",
"i.imgur.com/qqeiQ.png",
"i.imgur.com/c8Ffe.png",
"i.imgur.com/5BpLO.jpg",
"i.imgur.com/bKh45.jpg",
"i.imgur.com/WDqRM.jpg",
"i.imgur.com/9c2fD.jpg",
"i.imgur.com/Xqe43.jpg",
"i.imgur.com/q4196.jpg",
"i.imgur.com/BZGrP.jpg",
"i.imgur.com/BZGrP.jpg"
  ]

  attr_accessor :regex
  def initialize
    @regex = /^!(#{VALID_WORDS.join('|')})/i
  end
  def check(query)
    m = trycheck(query)
    # if it's too similar it will get the bot banned
    m = check(query) if m == @last_message
    @last_message = m
    return m
  rescue Exception => e
    puts e.message
    puts e.backtrace.join("\n")
    m = e.message
    "KINGSLY Uh oh... Tell hephaestus ASLAN broke. Exception: #{m.to_s}"
  end
  def trycheck(query)
    "ASLAN ! #{PICTURES.sample}"
  end
end