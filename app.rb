require 'rtesseract'
require 'sinatra'
require 'sinatra/json'
require 'haml'
require 'date'
require 'mongo'
require 'eth'
require 'mrz'

MANIFEST = {
  version: '1.0',
  name: 'Birthdoc',
  description: 'Stores your ID and shares your birth date',
  homepage_url: ENV['HOMEPAGE_URL'] || 'http://localhost:8000',
  picture_url: ENV['PICTURE_URL'] || 'https://avatars1.githubusercontent.com/u/42174428?s=200&v=4',
  address: ENV['APP_ADDRESS'] || '0x88032398beab20017e61064af3c7c8bd38f4c968',
  app_url: ENV['APP_URL'] || 'http://localhost:8000/data',
  app_reward: 0,
  app_dependencies: []
}.freeze
MESSAGE = 'I give permission to upload my birthdate, as stated on my Identity Document, to the Reputation Network'

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
    data = mrz_data(image.to_s)
    if data
      store_document(settings.db, signature, data)
      redirect '/done'
    else
      'no data found'
    end
  end
end

get '/data' do
  subject = parse_subject_header(request.env)
  return status 404 unless subject
  data = settings.db[:documents].find(public_key: subject).first
  return status 404 unless data
  json data['data']
end

get '/manifest' do
  json MANIFEST
end

def parse_subject_header(headers)
  Base64.decode64(headers['HTTP_X_PERMISSION_SUBJECT'] || 'null').gsub(/\A"|"\Z/, '')
end

def mrz_data(text) # TODO also IDs
  lines = mrz_lines(text)
  if lines
    data = MRZ.parse(lines)
    if data && data.valid_birth_date?
      {
        document_code: data.document_code,
        issuing_state: data.issuing_state,
        birthdate: data.birth_date
      }
    end
  end
rescue MRZ::InvalidFormatError
  # do nothing
end

def mrz_lines(text)
  lines = text.split("\n")
  first_mrz_line = lines.find { |line| (line.start_with?('ID') || line.start_with?('P<')) && line.size > 10 }
  lines = text.split(first_mrz_line)[1].split("\n")
  lines = lines.unshift(first_mrz_line)
  clean_mrz_lines(lines)
end

def clean_mrz_lines(lines)
  lines = lines.map { |line| line.strip }.select { |line| line.size > 10 }
  lines = lines.map do |line|
    line.split(' ').select { |part| part !~ /[a-z]/ }.join('') #lowercase characters invalid
  end
  if lines.size == 2
    lines.map { |line| line[0..43] } # TD3 size so 44 characters max
  elsif lines.size == 3
    lines.map { |line| line[0..29] } # TD1 size so 30 characters max
  end
end

def parse_mrz_birthdate(mrz_birthdate)
  date = Date._parse(mrz_birthdate)
  date[:year] = date[:year] - 100 if date[:year] > Date.today.year
  date
end

def store_document(db, signature, data)
  public_key = Eth::Utils.public_key_to_address(Eth::Key.personal_recover(MESSAGE, signature))
  db[:documents].insert_one(public_key: public_key.downcase, data: data)
end
