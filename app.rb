require 'rtesseract'
require 'sinatra'
require 'sinatra/json'
require 'haml'
require 'byebug'
require 'date'
require 'mongo'
require 'eth'

MANIFEST = {
  version: '1.0',
  name: 'Birthdoc',
  description: 'Stores your ID and shares your birth date',
  homepage_url: ENV['HOMEPAGE_URL'] || 'http://localhost:8081',
  picture_url: ENV['PICTURE_URL'] || 'https://avatars1.githubusercontent.com/u/42174428?s=200&v=4',
  address: ENV['APP_ADDRESS'] || '0x88032398beab20017e61064af3c7c8bd38f4c968',
  app_url: ENV['APP_URL'] || 'http://localhost:8081/data',
  app_reward: 0,
  app_dependencies: []
}.freeze
MESSAGE = 'I give permission to upload my ID'

set :db, Mongo::Client.new(ENV['MONGO_URL'] || 'mongodb://127.0.0.1:27017/rey-id')

get '/' do
  haml :index
end

get '/done' do
  haml :done
end

post '/upload' do
  @filename = params[:file][:filename]
  file = params[:file][:tempfile]
  signature= params[:signature]

  path = "./tmp/#{@filename}"
  File.open(path, 'wb') do |f|
    f.write(file.read)
    image = RTesseract.new(path)
    data = dni_data(image.to_s)
    if data
      store_dni(settings.db, signature, data)
      redirect '/done'
    else
      'no data found'
    end
  end
end

get '/data' do
  subject = parse_subject_header(request.env)
  return status 404 unless subject
  data = settings.db[:dnis].find(public_key: subject).first
  return status 404 unless data
  json data['data']
end

get '/manifest' do
  json MANIFEST
end

def store_dni(db, signature, data)
  public_key = Eth::Utils.public_key_to_address(Eth::Key.personal_recover(MESSAGE, signature))
  db[:dnis].insert_one(public_key: public_key.downcase, data: data)
end

def parse_subject_header(headers)
  Base64.decode64(headers['HTTP_X_PERMISSION_SUBJECT'] || 'null').gsub(/\A"|"\Z/, '')
end

def birthdate_from_machine_readable_lines(lines)
  date = Date._parse(lines[1][0..5])
  date[:year] = date[:year] - 100 if date[:year] > Date.today.year
  date
end

def dni_data(text)
  s = text.split('IDESP')
  if s.size > 1
    lines = s[1].split("\n")[0..2]
    {
      type: 'national_id',
      country: 'es',
      birthdate: birthdate_from_machine_readable_lines(lines)
    }
  end
end
