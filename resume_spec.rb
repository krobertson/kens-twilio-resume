require 'resume'
require 'nokogiri'
require 'spec'
require 'rack/test'

set :environment, :test

DataMapper.auto_migrate!

describe 'The Resume app' do
  include Rack::Test::Methods

  def app
    Sinatra::Application
  end

  it "should hang up when a call is complete with invalid guid" do
    post '/start', { 'CallGuid' => 'invalid', 'CallStatus' => 'completed' }
    last_response.ok?.should be_true

    doc = Nokogiri::XML(last_response.body)
    doc.xpath('/Response/Hangup').should_not be_empty
  end

  it 'should create a new call record and send sms on new call' do
    post '/start', { 'CallGuid' => 'test1', 'Caller' => '2095551234' }

    last_response.ok?.should be_true
    Call.first(:call_guid => 'test1').should_not be_nil
    
    doc = Nokogiri::XML(last_response.body)
    doc.xpath('/Response/Play').first.content.should == '/welcome.mp3'
    doc.xpath('/Response/Gather').first.attributes['action'].content.should == '/choice'
    doc.xpath('/Response/Gather/Play').first.content.should == '/menu.mp3'
  end

  it 'should mark a call as completed' do
    call = Call.create(:call_guid => 'test2', :caller => '2095551234')
    call.completed_at.should be_nil

    post '/start', { 'CallGuid' => 'test2', 'CallStatus' => 'completed' }
    last_response.ok?.should be_true

    call.reload
    call.completed_at.should_not be_nil
  end

  it 'should call me when they choose 5' do
    post '/choice', { 'CallGuid' => 'test1', 'Digits' => '5' }

    last_response.ok?.should be_true
    doc = Nokogiri::XML(last_response.body)
    doc.xpath('/Response/Play').first.content.should == '/calling_me.mp3'
    doc.xpath('/Response/Dial').first.content.should == '2096426287'
    doc.xpath('/Response/Redirect').first.content.should == '/choice'
  end
  
  it 'should get menu on empty digits' do
    post '/choice', { 'CallGuid' => 'test1', 'Digits' => '' }

    last_response.ok?.should be_true
    doc = Nokogiri::XML(last_response.body)
    doc.xpath('/Response/Gather').first.attributes['action'].content.should == '/choice'
    doc.xpath('/Response/Gather/Play').first.content.should == '/menu.mp3'
  end

  it 'should get menu on missing digits' do
    post '/choice', { 'CallGuid' => 'test1' }

    last_response.ok?.should be_true
    doc = Nokogiri::XML(last_response.body)
    doc.xpath('/Response/Gather').first.attributes['action'].content.should == '/choice'
    doc.xpath('/Response/Gather/Play').first.content.should == '/menu.mp3'
  end
  
  def test_choice(choice, expected_mp3)
    post '/choice', { 'CallGuid' => 'test1', 'Digits' => choice.to_s }

    last_response.ok?.should be_true
    doc = Nokogiri::XML(last_response.body)
    doc.xpath('/Response/Gather').first.attributes['action'].content.should == '/choice'
    doc.xpath('/Response/Gather/Play').first.content.should == expected_mp3
    doc.xpath('/Response/Redirect').first.content.should == '/choice'
  end

  it 'should play about.mp3 when they choose 1' do
    test_choice(1, '/about.mp3')
  end

  it 'should play employment.mp3 when they choose 2' do
    test_choice(2, '/employment.mp3')
  end

  it 'should play sites.mp3 when they choose 3' do
    test_choice(3, '/sites.mp3')
  end

  it 'should play code.mp3 when they choose 4' do
    test_choice(4, '/code.mp3')
  end

end
