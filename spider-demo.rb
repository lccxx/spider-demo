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


# 去亚马逊获取网页
def amazon_get(path)
  p "获取页面 #{path}"

  Net::HTTP.start("www.amazon.com", use_ssl: true) { |http|         # 打开到亚马逊服务器的 HTTPS 连接
    http.verify_mode = 0                                            # 不验证 HTTPS 证书
    req = Net::HTTP::Get.new(path)                                  # 创建一个 HTTP GET 请求
    req["User-Agent"] = USER_AGENTS[(rand * USER_AGENTS.size).to_i] # 使用一个随机的 User-Agent 请求头
    
    http.request(req)          # 发起请求，获取响应（ruby 的特性，自动返回，不需要额外写 return ）
  }
end

# 迭代处理每一个关键字
KEYWORKS.each { |kw|
  res = amazon_get("/s?k=#{kw}")  # 去亚马逊查询关键字
  doc = Nokogiri::HTML(p res.body)     # 解析网页
  page_count = doc.css("ul.a-pagination li.a-disabled").last  # 获取网页中的页码元素
  page_count_num = page_count.text.to_i if page_count         # 获取页码数字的值

  docs = [ doc ]   # 页面数组，因为有多个翻页

  (2..page_count_num).each { |page|                         # 获取多个翻页页面
    res = amazon_get("/s?k=#{URI.encode kw}&page=#{page}")  # 去亚马逊查询对应的关键字，对应 page 的页面
    docs << Nokogiri::HTML(res.body)                        # 把页面扔进页面数组
  } if page_count_num

  docs.each { |doc|                                         # 遍历页面数组，查询图片
    p doc.css('img.s-image').each { |img|                   # 遍历页面中的商品图片，并且打印出每页的图片数量
      img_src = img.attribute("src")                        # 获取图片的 src 属性
      img_src_value = img_src.value if img_src              # 获取图片 src 属性的值
      p img_src_value = img_src_value.sub(/UL\d+_.jpg/, "UL960_.jpg") if img_src_value    # 替换小图片为大图片
      filename = File.basename img_src_value                                              # 确定图片文件名称，用于下载
      file = File.join(DIR, "images", filename)                                           # 确定图片下载路径
      next if File.exists?(file)                       # 如果图片已经下载过了，就跳过
      open(file, "wb") { |fo| fo.write Net::HTTP.get URI img_src_value }    # 下载并且写入文件
    }.size
  }
}
