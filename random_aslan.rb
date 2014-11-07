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
"https//i.imgur.com/7CKen57.png",
"https//i.imgur.com/qTfcv6z.jpg",
"https//i.imgur.com/jr5tN1Z.jpg",
"https//i.imgur.com/nwsnucQ.jpg",
"https//i.imgur.com/esgubkS.jpg",
"https//i.imgur.com/0fhs9Hn.png",
"https//i.imgur.com/Gm2ZZHW.jpg",
"https//i.imgur.com/LUUFZSi.jpg",
"https//i.imgur.com/KZ0INJo.jpg",
"https//i.imgur.com/kIMVlYR.jpg",
"https//i.imgur.com/ovCFSmc.jpg",
"https//i.imgur.com/7EJWRLS.jpg",
"https//i.imgur.com/btHzG6k.jpg",
"https//i.imgur.com/QodDNpD.jpg",
"https//i.imgur.com/aC4FM2d.jpg",
"https//i.imgur.com/G4jATsN.jpg",
"https//i.imgur.com/vXqSR1S.jpg",
"https//i.imgur.com/4LP72lu.jpg",
"https//i.imgur.com/9qDdnwR.jpg",
"https//i.imgur.com/BUSdLT1.jpg",
"https//i.imgur.com/otKft3L.jpg",
"https//i.imgur.com/QfVdLQN.jpg",
"https//i.imgur.com/aeMsfbO.jpg",
"https//i.imgur.com/VE5vMzp.jpg",
"https//i.imgur.com/kYQ2DDB.jpg",
"https//i.imgur.com/m10IMxd.jpg",
"https//i.imgur.com/YrwA2Ky.jpg",
"https//i.imgur.com/zX1rwI4.jpg",
"https//i.imgur.com/fuWZ6P6.jpg",
"https//i.imgur.com/oCQrpUE.jpg",
"https//i.imgur.com/wqbdZYD.jpg",
"https//i.imgur.com/iYHw5Yu.jpg",
"https//i.imgur.com/MXfZXTC.jpg",
"https//i.imgur.com/XgeYHxU.jpg",
"https//i.imgur.com/l5845Fb.jpg",
"https//i.imgur.com/wJc1ACo.jpg",
"https//i.imgur.com/XjtAer0.jpg",
"https//i.imgur.com/9gIywT9.jpg",
"https//i.imgur.com/IUyi5za.jpg",
"https//i.imgur.com/BbCUuNl.jpg",
"https//i.imgur.com/kkESxWN.jpg",
"https//i.imgur.com/cyj4tUn.jpg",
"https//i.imgur.com/tIVg5Kv.jpg",
"https//i.imgur.com/UvsL62m.jpg",
"https//i.imgur.com/a40LqZn.jpg",
"https//i.imgur.com/PPG9wBk.jpg",
"https//i.imgur.com/ZHcPU5i.jpg",
"https//i.imgur.com/I7d4jrW.jpg",
"https//i.imgur.com/LYdvJcL.jpg",
"https//i.imgur.com/yU4xEVl.jpg",
"https//i.imgur.com/CNRihXs.jpg",
"https//i.imgur.com/I6EZH5i.jpg",
"https//i.imgur.com/2XdS7PI.jpg",
"https//i.imgur.com/gWh7v08.jpg",
"https//i.imgur.com/wjvAAPY.jpg",
"https//i.imgur.com/y5gwYpS.jpg",
"https//i.imgur.com/tA6aLnc.jpg",
"https//i.imgur.com/TTZrfuz.gif",
"https//i.imgur.com/5KMRbyX.gif",
"https//i.imgur.com/hwYIXXl.gif",
"https//i.imgur.com/JkrNV.jpg",
"https//i.imgur.com/qMfMl.gif",
"https//i.imgur.com/vm46R.gif",
"https//i.imgur.com/UsG8C.jpg",
"https//i.imgur.com/pOh7M.jpg",
"https//i.imgur.com/t4wez.jpg",
"https//i.imgur.com/xDMSO.jpg",
"https//i.imgur.com/rZpTf.jpg",
"https//i.imgur.com/IlA6i.jpg",
"https//i.imgur.com/swjct.jpg",
"https//i.imgur.com/1p6Qh.jpg",
"https//i.imgur.com/h9yfb.jpg",
"https//i.imgur.com/bskqb.jpg",
"https//i.imgur.com/6unYj.jpg",
"https//i.imgur.com/f46CY.jpg",
"https//i.imgur.com/xszgf.jpg",
"https//i.imgur.com/qUMa4.jpg",
"https//i.imgur.com/Z8eku.png",
"https//i.imgur.com/oA0RU.png",
"https//i.imgur.com/s1rbI.png",
"https//i.imgur.com/YIVhC.png",
"https//i.imgur.com/iXeO1.png",
"https//i.imgur.com/DCQsH.jpg",
"https//i.imgur.com/ufdPy.jpg",
"https//i.imgur.com/M59kL.jpg",
"https//i.imgur.com/5v9bm.jpg",
"https//i.imgur.com/K8FMP.png",
"https//i.imgur.com/aa71R.jpg",
"https//i.imgur.com/nvKTt.jpg",
"https//i.imgur.com/GDCgO.jpg",
"https//i.imgur.com/JKWO9.jpg",
"https//i.imgur.com/D25UK.jpg",
"https//i.imgur.com/J02ko.jpg",
"https//i.imgur.com/XB8Cx.jpg",
"https//i.imgur.com/liRmn.jpg",
"https//i.imgur.com/EutQH.jpg",
"https//i.imgur.com/gCr2M.jpg",
"https//i.imgur.com/c0BeE.jpg",
"https//i.imgur.com/yHUyD.jpg",
"https//i.imgur.com/njODR.jpg",
"https//i.imgur.com/Dl4BV.jpg",
"https//i.imgur.com/Bxgh4.jpg",
"https//i.imgur.com/bcjqd.jpg",
"https//i.imgur.com/HcbVW.jpg",
"https//i.imgur.com/a0vIz.jpg",
"https//i.imgur.com/FVANc.jpg",
"https//i.imgur.com/V4NUN.png",
"https//i.imgur.com/dBqxt.jpg",
"https//i.imgur.com/abd7q.jpg",
"https//i.imgur.com/j3LTf.png",
"https//i.imgur.com/y0A2U.jpg",
"https//i.imgur.com/X5Qol.png",
"https//i.imgur.com/B9BrE.png",
"https//i.imgur.com/qqeiQ.png",
"https//i.imgur.com/c8Ffe.png",
"https//i.imgur.com/5BpLO.jpg",
"https//i.imgur.com/bKh45.jpg",
"https//i.imgur.com/WDqRM.jpg",
"https//i.imgur.com/9c2fD.jpg",
"https//i.imgur.com/Xqe43.jpg",
"https//i.imgur.com/q4196.jpg",
"https//i.imgur.com/BZGrP.jpg",
"https//i.imgur.com/BZGrP.jpg"
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