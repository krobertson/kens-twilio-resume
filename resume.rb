require 'rubygems'
require 'coderay'
require 'dm-core'
require 'haml'
require 'sinatra'
require 'twilio'

class Call
  include DataMapper::Resource

  property :id,           Serial
  property :created_at,   DateTime, :default => lambda { Time.now }
  property :completed_at, DateTime

  property :caller,       String
  property :call_guid,    String
end

DataMapper.setup(:default, ENV['DATABASE_URL'] || "sqlite3:///#{Dir.pwd}/test.db")

before { headers "Content-Type" => "text/xml" }

get '/' do
  headers "Content-Type" => "text/html; charset=utf-8"
  haml :index
end

post '/start' do
  # See if the call is completed
  if params['CallStatus'] == 'completed'
    call = Call.first(:call_guid => params['CallGuid'])
    return Twilio::Verb.new { |v| v.hangup }.response unless call

    # mark it as completed and save
    call.completed_at = Time.now
    call.save
    return ''
  else
    call = Call.create(:call_guid => params['CallGuid'], :caller => params['Caller'])

    # send me a text message to let me know!
    Twilio.connect(ENV['TWILIO_SID'], ENV['TWILIO_TOKEN'])
    Twilio::Sms.message(call.caller, '2096426287', "I'm checking out your resume!")

    # play the welcome message
    return Twilio::Verb.new do |v|
      v.play('/welcome.mp3')
      v.gather(:timeout => 10, :action => '/choice') {
        v.play('/menu.mp3')
      }
    end.response
  end
end

post '/choice' do
  # validate the call
  call = Call.first(:call_guid => params['CallGuid'])
  return Twilio::Verb.new { |v| v.hangup }.response unless call

  # if they chose 5, have it call me and redirect back afterwards
  if params['Digits'] == '5'
    return Twilio::Verb.new do |v|
      v.play('/calling_me.mp3')
      v.dial('2096426287')
      v.redirect('/choice')
    end.response
  end

  # figure out which section to play
  section_mp3 = case params['Digits']
  when '1' then '/about.mp3'
  when '2' then '/employment.mp3'
  when '3' then '/sites.mp3'
  when '4' then '/code.mp3'
  end
  
  if section_mp3
    # play the selected section
    return Twilio::Verb.new do |v|
      v.gather(:timeout => 10, :action => '/choice') {
        v.play(section_mp3)
      }
      v.redirect('/choice')
    end.response
  else
    # give them the menu again
    return Twilio::Verb.new do |v|
      v.gather(:timeout => 10, :action => '/choice') {
        v.play('/menu.mp3')
        v.redirect('/choice')
      }
    end.response
  end
end