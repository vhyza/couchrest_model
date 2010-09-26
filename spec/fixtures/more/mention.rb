class Mention < CouchRest::Model::Base
  use_database DB

  property :title, String
  property :author, String
  property :url, String
  property :content, String
  property :published_at, Time

  timestamps!


  view_by :title, :stale => "ok"


  def self.update_view
    Mention.design_doc['views'].keys.each do |view|
      RestClient.get "#{Mention.database}/#{Mention.design_doc_id}/_view/#{view}?limit=0"
    end
  end
end
