# encoding: utf-8
require 'curb'
require 'nokogiri'

# Fetch verified proxy from http://www.cnproxy.com/
class ProxyList

  def initialize
    @lists = []
    @urls = []
    (1..10).each do |i|
      @urls << "http://www.cnproxy.com/proxy#{i}.html"
    end
  end

  def fetch_list
    @urls.each do |url|
      @lists += proxys_in_url(url)
    end
    @lists.uniq!
    puts "Fetched proxys #{@lists.size}:"
    puts @lists.join(" ")
    return self
  end

  def verify_list
    max_thread = 30
    final_lists = []
    0.step(@lists.size, max_thread).each do |i|
      treads = []
      top = (i + max_thread - 1)
      top = @lists.size - 1 if top > @lists.size - 1
      (i..top).each do |k|
        proxy = @lists[k]
        treads << Thread.new do
          final_lists << proxy if verify_proxy(proxy)
        end
      end
      treads.map(&:join)
    end

    puts
    puts "Verified proxys #{final_lists.size}:"
    puts final_lists.join(" ")
    @lists = final_lists
    final_lists
  end

  private

  def calc_port(values, expr)
    port = eval("#{values};#{expr}")
  end

  def proxys_in_url(url)
    proxys = []
    c = Curl::Easy.new do |curl|
      curl.url = url
      curl.timeout = 30
    end

    c.perform

    doc = Nokogiri::HTML(c.body_str)

    port_express = doc.search("script")[0].text.strip

    tds = doc.search("#proxylisttb table:last tr td:first")

    tds[1..-1].each do |td|
      text = td.text
      r = /(?<ip>.+)document\.write\("\:"\+(?<port_expr>.+)\)/.match(text)
      port = calc_port(port_express, r[:port_expr]) rescue nil
      proxys << "#{r[:ip]}:#{port}" if port
    end

    return proxys
  rescue => e
    # puts e.message
    return proxys
  end

  def verify_proxy(proxy)
    ip, port = proxy.split(":")
    c = Curl::Easy.new do |curl|
      curl.url = "http://www.baidu.com"
      curl.proxy_port = port.to_i
      curl.proxy_url = ip
      curl.timeout = 20
    end

    c.perform
    # puts c.body_str
    if c.body_str.force_encoding("utf-8").index("百度一下，你就知道")
      # puts "yes"
      return true
    else
      # puts "no"
      return false
    end

  rescue => e
    puts e.message
    return false
  end

end

if $0 == __FILE__
  pl = ProxyList.new
  pl.fetch_list.verify_list

  # 再一次
  pl.verify_list
  pl.verify_list
  pl.verify_list
  pl.verify_list
  pl.verify_list
  pl.verify_list
end