#!/usr/bin/env ruby

require 'net/http'
require 'nokogiri'

# 防止屏蔽，用于假冒的 User-Agent 的数组
USER_AGENTS = [
	"Mozilla/5.0 (iPhone; CPU iPhone OS 11_0 like Mac OS X) AppleWebKit/604.1.38 (KHTML, like Gecko) Version/11.0 Mobile/15A372 Safari/604.1",
	"Mozilla/5.0 (iPad; CPU OS 11_0 like Mac OS X) AppleWebKit/604.1.34 (KHTML, like Gecko) Version/11.0 Mobile/15A5341f Safari/604.1",
	"Mozilla/5.0 (Linux; Android 8.0.0; Pixel 2 XL Build/OPD1.170816.004) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/73.0.3683.103 Mobile Safari/537.36",
	"Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/73.0.3683.103 Safari/537.36",
	"Mozilla/5.0 (Linux; x64; rv:65.0) Gecko/20100101 Firefox/65.0",
	"Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:65.0) Gecko/20100101 Firefox/65.0"
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

    # 找不到图片地址也放弃
    return p [ img_src, page_url ] if not img_src

		img_url = img_src.value.strip

		# 新增一列写入另外一个 csv
    File.open(TO_FILE, "ab") { |fo| fo.puts "#{p page_url},#{p img_url}" }
	}
end


def work
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


  # 开启三个工作线程来获取图片
  3.times {
    Thread.new {
      loop {
        page_url = PAGE_URLS.shift
        break if page_url.nil?

        get_img_url_append_to_file page_url

        sleep(3 + rand * 9)
      }
    }
    sleep(3 + rand * 9)
  }

  return PAGE_URLS.size
end

loop {
  # 全部任务已完成
  if PAGE_URLS.size == 0
    page_urls_count = work

    # 全部任务已完成并且没有遗漏
    break if page_urls_count <= IMG_URLS.size
  end

  sleep 9
}
