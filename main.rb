require 'open-uri'
require 'rss'
require 'nokogiri'
require 'feedjira'
require 'sinatra'
require 'sequel'
require 'date'
require 'json'

db = Sequel.sqlite('news-sentiment')

get '/' do 
    # @articles = db[:articles]
    # @articles = @articles.all.map do |a|
    #     puts a[:pub_date]
    #     date = DateTime.strptime(a[:pub_date], "%Y-%m-%d %H:%M:%S").to_date
    #     {:pub_date => date, :news_source => a[:news_source], :sentiment_value => a[:sentiment_value]}
    # end
    # @date2articles = Hash.new([])
    # @articles.each {|a| @date2articles[a[:pub_date]] += [a]}
    # @date2sentiment = {}
    # @date2articles.each do |k, v|
    #     sum = v.reduce(0) {|sum, a| sum + a[:sentiment_value]}
    #     mean = sum.to_f / v.size
    #     @date2sentiment[k] = mean
    # end 
    erb :index
end

get '/get_date2sentiment/' do
   @articles = db[:articles]
    @articles = @articles.all.map do |a|
        puts a[:pub_date]
        date = DateTime.strptime(a[:pub_date], "%Y-%m-%d %H:%M:%S").to_date
        {:pub_date => date, :news_source => a[:news_source], :sentiment_value => a[:sentiment_value]}
    end
    @date2articles = Hash.new([])
    @articles.each {|a| @date2articles[a[:pub_date]] += [a]}
    @date2sentiment = {}
    @date2articles.each do |k, v|
        sum = v.reduce(0) {|sum, a| sum + a[:sentiment_value]}
        mean = sum.to_f / v.size
        @date2sentiment[k] = mean
    end 
    return {"dates" => @date2sentiment.keys, "sentiments" => @date2sentiment.values}.to_json
end

# def test
#     db = Sequel.sqlite('news-sentiment')
#     @articles = db[:articles]
#     @articles = @articles.all.map do |a|
#         puts a[:pub_date]
#         date = DateTime.strptime(a[:pub_date], "%Y-%m-%d %H:%M:%S").to_date
#         {:pub_date => date, :news_source => a[:news_source], :sentiment_value => a[:sentiment_value]}
#     end
#     @date2articles = Hash.new([])
#     @articles.each {|a| @date2articles[a[:pub_date]] += [a]}
#     return @date2articles
# end

def update_db()
    db = Sequel.sqlite('news-sentiment')
    articles = db[:articles]
    new_articles = read_rss()
    new_articles.each do |e|
        articles.insert(
            :news_source => 'CNN',
            :pub_date => e[:date],
            :sentiment_value => e[:sentiment]
        )
    end
end 

def read_rss(rss_url="http://rss.cnn.com/rss/cnn_topstories.rss")
    word2value = load_afinn()
    stories = []
    feed = Feedjira::Feed.fetch_and_parse(rss_url)
    entries = feed.entries.select {|e| not e.url.include? "video"}
    entries = entries.select {|e| not e.url.include? "gallery"}
    return entries.map do |e|
        puts e.url
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

