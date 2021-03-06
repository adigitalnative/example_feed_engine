require 'spec_helper'

describe "API feeds/user/... ", :type => :api do
  let!(:user) { FactoryGirl.create(:user) }
  let!(:user2) { FactoryGirl.create(:user, display_name: "user2",
                                    email: "user2@badger.com") }
  let(:token) { user.authentication_token }

  before do
    5.times do
      item = FactoryGirl.create(:text_item, :user => user)
    end
    5.times do
      item = FactoryGirl.create(:image_item, :user => user)
    end
    5.times do
      item = FactoryGirl.create(:link_item, :user => user)
    end
    5.times do
      item = FactoryGirl.create(:text_item, body: "user2 comment", :user => user2)
    end
  end

  context "creating feed items via the API" do
    let(:url) { "http://api.example.com#{new_api_item_path(user)}" }

    it "creates a text_item via the api" do
      body = '{"type":"TextItem","body": "New text post via the api."}'
      post "#{url}.json", :token => token, :body => body

      last_response.status.should == 201

      new_post = user.stream_items.last.streamable
      new_post.body.should == "New text post via the api."
      new_post.should be_a(TextItem)
    end

    it "creates a link_item via the api" do
      body = '{"type":"LinkItem","comment": "I love Flash games", "link_url": "http://www.games.com/awesome.swf"}'
      post "#{url}.json", :token => token, :body => body

      last_response.status.should == 201

      new_post = user.stream_items.last.streamable
      new_post.comment.should == "I love Flash games"
      new_post.url.should == "http://www.games.com/awesome.swf"
      new_post.should be_a(LinkItem)
    end

    it "creates an image_item via the api" do
      body = '{"type":"ImageItem","comment": "This image is cool.", "image_url": "http://foo.com/cat.jpg"}'
      post "#{url}.json", :token => token, :body => body

      last_response.status.should == 201

      new_post = user.stream_items.last.streamable
      new_post.comment.should == "This image is cool."
      new_post.url.should == "http://foo.com/cat.jpg"
      new_post.should be_a(ImageItem)
    end

    it "responds with errors for an invalid post" do
      body = '{"type":"ImageItem","comment": "This image is cool.", "image_url": "http://foo.com/cat.html"}'
      post "#{url}.json", :token => token, :body => body

      last_response.status.should == 406
      last_response.body.should include("must be jpg, bmp, png, or gif and start with http/https")
    end

    it "prevents a user from posting to another user's feed" do
      body = '{"type":"ImageItem","comment": "An insidious evil post.", "image_url": "http://troll.com/cat.jpg"}'
      post "#{url}.json", :token => user2.authentication_token, :body => body

      last_response.status.should == 401

      user.image_items.last.comment.should_not == "An insidious evil post."

    end

  end

  context "getting a feed item" do
    default_url_options[:host] = "api.example.com"
    it "returns a json representation for a text post" do
      item = user.text_items.last
      stream_item = user.stream_items.where(:streamable_id => item.id).where(:streamable_type => item.class.name).first
      text_item_url = "http://api.example.com#{api_item_path(user, stream_item)}"
      get "#{text_item_url}.json", :token => token

      resp = JSON.parse(last_response.body)
      resp["id"].should == item.id
      resp["type"].should == item.class.name
      Date.parse(resp["created_at"]).should == Date.parse(item.created_at.to_s)
      resp["body"].should == item.body
      resp["link"].should == api_item_url(item.user, item)
    end
  end

  context "getting the user's feed items" do
    let(:url) { "http://api.example.com#{api_feed_path(user)}" }
    before(:each) { get "#{url}.json", :token => token }

    it "returns an array of most recent stream items as json" do
      stream_items = user.stream_items.order("created_at DESC")[0..11]

      feed = JSON.parse(last_response.body)
      feed["items"]["most_recent"].count.should == 12
      last_response.status.should == 200

    end

    it "includes item details in the response" do
      feed = JSON.parse(last_response.body)
      feed["name"].should == user.display_name
      feed["id"].should == user.id
      feed["private"].should == false
      feed["link"].should == api_feed_url(user)
      feed["items"]["first_page"].should == api_feed_url(user, :page => 1)
      feed["items"]["last_page"].should == api_feed_url(user, :page => (user.stream_items.count/12.0).ceil)
    end

    it "formats the json response for an image_item " do
      new_url = "http://worace.com/workshop.png"
      comment = "wonderful wares whenever worace wants"

      new_image_item = user.image_items.create(:comment => comment, :url => new_url)

      #set the created_at to make the item come first
      user.stream_items.find_by_streamable_id(new_image_item.id).created_at = Date.today+100000

      get "#{url}.json", :token => token
      feed = JSON.parse(last_response.body)

      expected_keys = ["type", "image_url", "created_at", "id", "feed", "link", "refeed", "refeed_link"]

      expected_keys.each do |key|
        feed["items"]["most_recent"].first.keys.should include(key)
      end

    end
  end
end
