#!/usr/bin/env ruby

require 'net/http'
require 'nokogiri'

# 防止屏蔽，用于假冒的 User-Agent 的数组
USER_AGENTS = [
	"Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/73.0.3683.103 Safari/537.36"
]

# 当前脚本所在目录
DIR = File.dirname(File.absolute_path(__FILE__))

# 从哪个文件读取
FROM_FILE = File.join(DIR, "AmazoncompulloverWom01.csv")

# 写到哪个文件去
TO_FILE = File.join(DIR, "kju.csv")


# 已经获取到的图片
IMG_URLS = [ ]

# 需要获取的页面
PAGE_URLS = [ ]


def get_img_url_append_to_file(page_url)
  # 已经获取到的就跳过
  return if IMG_URLS.include?(page_url)

  page_uri = URI page_url
  Net::HTTP.start(page_uri.host, use_ssl: page_uri.scheme == 'https') { |http|
    http.verify_mode = 0
    req = Net::HTTP::Get.new(page_uri.path)
    req["User-Agent"] = USER_AGENTS[(rand * USER_AGENTS.size).to_i]

    res = http.request(req)

    # 被拒绝就放弃
    return p [ req.to_hash, res.code ] if res.code != "200"

    doc = Nokogiri::HTML(res.body)
    img = doc.css("#imgTagWrapperId img").first if doc
    img_src = img.attribute("data-old-hires") if img
    img_url = img_src.value.strip if img_src
    img_url = img.attribute("src").value.strip if img && img_url.nil?

    # 找不到图片地址也放弃
    return p [ img_url, img, page_url ] if img_url.nil? || img_url.size == 0

    # 新增一列写入另外一个 csv
    File.open(TO_FILE, "ab") { |fo| fo.puts "#{p page_url},#{p img_url}" }
  }
end


def work
  IMG_URLS.clear
  PAGE_URLS.clear

  File.foreach(TO_FILE) { |line|
    IMG_URLS << line.split(",")[0].strip
  } if File.exists?(TO_FILE)

  File.foreach(FROM_FILE) { |line|
    # 拆分行为列
    fields = line.split(",")

    # url 在第一列
    url = fields[0].strip
    url = "https://#{url}" if not url[/^http/]

    PAGE_URLS << url
  }


  # 开启39个工作线程来获取图片
  99.times {
    Thread.new {
      loop {
	begin
	  page_url = PAGE_URLS.shift
	  break if page_url.nil?

	  get_img_url_append_to_file page_url
        rescue => e
        end

        sleep(1 + rand * 3)
      }
    }
    sleep(1 + rand * 3)
  }

  return PAGE_URLS.size
end

loop {
  # 全部任务已完成
  if PAGE_URLS.size == 0
    # 全部任务已完成并且没有遗漏
    break if work <= IMG_URLS.size
  end

  sleep 9
}
