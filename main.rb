require 'open-uri'
require 'rss'
require 'nokogiri'
require 'feedjira'
require 'sinatra'
require 'date'
require 'json'

get '/' do
    erb :index
end

get '/get_date2sentiment/' do
    @articles = []
    File.open('articles.json', 'r') do |f|
        @articles = JSON.parse(f.read())
    end
    @articles = @articles.each do |a|
        a["pub_date"] = DateTime.strptime(a["pub_date"], "%Y-%m-%d %H:%M:%S").to_date
    end
    @date2articles = Hash.new([])
    @articles.each {|a| @date2articles[a["pub_date"]] += [a]}
    @date2sentiment = {}
    @date2articles.each do |k, v|
        sum = v.reduce(0) {|sum, a| sum + a["sentiment_value"]}
        mean = sum.to_f / v.size
        @date2sentiment[k] = mean
    end 
    sorted_keys = @date2sentiment.keys.sort
    sorted_vals = sorted_keys.map {|k| @date2sentiment[k]}
    return {"dates" => sorted_keys, "sentiments" => sorted_vals}.to_json
end

def update_db()
    articles = []
    File.open('articles.json', 'r') { |f| articles = JSON.parse(f.read())}
    new_articles = read_rss()
    new_articles.each do |e|
        articles.push({:news_source => 'CNN',
            :pub_date => e[:date].to_s.sub("UTC", ""),
            :sentiment_value => e[:sentiment]
        })
    end
    File.open('articles.json', 'w') {|f| f.write(JSON.dump(articles))}
end 

def read_rss(rss_url="http://rss.cnn.com/rss/cnn_topstories.rss")
    word2value = load_afinn()
    stories = []
    feed = Feedjira::Feed.fetch_and_parse(rss_url)
    entries = feed.entries.select {|e| not e.url.include? "video"}
    entries = entries.select {|e| not e.url.include? "gallery"}
    return entries.map do |e|
        page = Nokogiri::HTML(open(e.url))
        content = page.css('div.cnn_strycntntlft').css('p').inner_html
        sentiment = get_sentiment_value(content, word2value)
        {:date => e.published, :sentiment => sentiment}
    end
end

def load_afinn(path='AFINN/AFINN-111.txt')
    word2value = Hash.new(:no_val)
    File.open(path).each do |line| 
        word_val_pair = line.strip().split("\t")
        word2value[word_val_pair[0]] = word_val_pair[1].to_i()
    end
    return word2value
end

def get_sentiment_value(corpus, word2value)
    words = corpus.scan(/'[^']*'|"[^"]*"|[(:)]|[^(:)\s]+/)
    values = words.map {|word| word2value[word]}
    values = values.select {|i| i != :no_val}
    return values.inject(:+).fdiv values.size
end

