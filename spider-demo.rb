#!/usr/bin/env ruby

require "fileutils"
require 'net/http'
require 'nokogiri'

# 防止屏蔽，用于假冒的 User-Agent 的数组
USER_AGENTS = [
	"Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/73.0.3683.103 Safari/537.36",
  "Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:66.0) Gecko/20100101 Firefox/66.0"
]

# 搜索关键字
KEYWORKS = [ "pullover", "Double-breasted" ]

# 当前脚本所在目录
DIR = File.dirname(File.absolute_path(__FILE__))

# 创建图片文件夹
FileUtils.mkpath File.join(DIR, "images")


def amazon_get(path, args)
  Net::HTTP.start("www.amazon.com", use_ssl: true) { |http|
    http.verify_mode = 0
    req = Net::HTTP::Get.new("#{path}#{args && args.is_a?(Hash) ? "?#{URI.encode_www_form(args.to_a)}" : ""}")
    req["User-Agent"] = USER_AGENTS[(rand * USER_AGENTS.size).to_i]
    
    http.request(req)
  }
end

KEYWORKS.each { |kw|
  res = amazon_get("/s", { k: kw })
  doc = Nokogiri::HTML(res.body)
  page_count = doc.css("ul.a-pagination li.a-disabled").last
  page_count_num = page_count.text.to_i if page_count

  docs = [ doc ]

  (2..page_count_num).each { |page|
    res = amazon_get("/s", { k: kw, page: page })
    docs << Nokogiri::HTML(res.body)
  } if page_count_num

  docs.each { |doc|
    p doc.css('img.s-image').each { |img|
      img_src = img.attribute("src")
      p img_src_value = img_src.value if img_src
      filename = File.basename img_src_value
      file = File.join(DIR, "images", filename)
      next if File.exists?(file)
      open(file, "wb") { |fo| fo.write Net::HTTP.get URI img_src_value }
    }.size
  }
}
