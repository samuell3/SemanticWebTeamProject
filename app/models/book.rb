require "net/http"
class Book < ActiveRecord::Base

  has_many :user_book_relation
  attr_accessible :name, :author, :abstract, :numberOfPages, :publisher, :image_link, :amazon_link

  OpenSSL::SSL::VERIFY_PEER = OpenSSL::SSL::VERIFY_NONE #stupid trick

  $app_id = "383644138456712"
  $app_secret = "6098a751b6d9b829b245fef8ec1f3408"  

  def self.search_friends_who_read_book(user_id, book_title)
    res = []
    friends_books = self.search_friends_books(user_id)
    friends_books.each_key do |friend_id|
      friends_books[friend_id].each do |book_id|
        book = Book.find(book_id)
        res << friend_id if self.equals_title?(book_title, book.name)
      end
    end
    res
  end

  def self.amazon_link(book)
    "http://www.amazon.com/s/ref=nb_sb_ss_c_0_4?url=search-alias%3Dstripbooks&field-keywords=#{book.gsub(" ", "%20")}"
  end

  def self.google_link(book)
    google_url = "https://play.google.com/store/search?q=#{book.gsub(" ", "%20")}&c=books"
  end

  def self.search_google(book)
    res = {}
    books = GoogleBooks.search(book) 
    book = books.first
    res.store("sale_info", book.sale_info)
    res.store("title", book.title)
    res.store("image_link", book.image_link)
    res      
  end

  def self.search_dbpedia(book)
    res = {}
    sparql = SPARQL::Client.new("http://dbpedia.org/sparql")
    queryString="
      PREFIX rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#>
      PREFIX rdfs: <http://www.w3.org/2000/01/rdf-schema#>
      PREFIX dbpedia: <http://dbpedia.org/resource/>
      PREFIX ontology: <http://dbpedia.org/ontology/>
      PREFIX dct: <http://purl.org/dc/terms/>
      select distinct ?name ?book ?author ?abstract ?numberOfPages ?publisher
      where {
        ?book rdf:type ontology:Book;
              dbpprop:name ?name;   
              ontology:abstract ?abstract;
              dbpprop:author ?author.
        OPTIONAL {
        ?book ontology:numberOfPages ?numberOfPages;
              dbpprop:publisher ?publisher
        }
        FILTER (langMatches(lang(?abstract), 'EN'))
        FILTER (lcase(str(?name)) = lcase('#{book}'))
      }LIMIT 1"
    query = sparql.query(queryString)
    query.each_solution do |solution|
      res.store("author", solution.author) if solution.bound?('author')
      res.store("abstract", solution.abstract.to_s)
    end
    res
  end

  def self.search_facebook_friends_books()
    url = "https://graph.facebook.com/v2.1/me?friends%7Bbooks%7D&access_token=#{$token}"
    uri = URI.parse(url)
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    http.verify_mode = OpenSSL::SSL::VERIFY_PEER
    request = Net::HTTP::Get.new(uri.request_uri)
    response = http.request(request)
  end



  def self.search_friends_books(user_id)
    res = {}
    friendships = Friendship.where(user_id: user_id)
    friends_ids = []
    friendships.each { |friendship| friends_ids << friendship.friend_id }
    friends_ids.each do |id|
      books_ids = [] 
      user_book_relations = UserBookRelation.where(user_id: id)
      user_book_relations.each { |ubr| books_ids << Book.find(ubr.book_id).id }
      res.store(id, books_ids)
    end
    res 
  end

  def self.equals_title?(s1, s2)
    s1 = s1.downcase.gsub("-", " ").split(" ") - ["a", "the"]
    s2 = s2.downcase.gsub("-", " ").split(" ") - ["a", "the"]
    s1 == s2
  end
end
