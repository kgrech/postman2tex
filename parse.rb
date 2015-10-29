#!/usr/bin/env ruby
require 'json'
require 'erubis'
require 'fileutils'

def write_file(file_name, text)
  File.open(file_name, 'w') do |f|
    f.write text
  end	
end

def process_erb_file(erb_filename, output_filename, context)
  input = File.read(erb_filename)
  eruby = Erubis::Eruby.new(input)    # create Eruby object
  puts "Generating file: #{output_filename}..."
  write_file(output_filename, eruby.evaluate(context))
end

def write_listing(file_name, text)
  lines = text.split(/\n/).map do |line| 
  	chomped = line[0..49]
  	if (chomped.length != line.length)
  		chomped = "#{chomped}..."
  	end
  	chomped
  end
  File.open(file_name, 'w') do |f|
    lines.each { |line| f.puts line}
  end	
end


OUTPUT = 'gen'
SOURCE = "#{OUTPUT}/source"
TEMPLATE_DIR = 'templates'

folder = ARGV.shift
raise 'postman collection folder is missing' unless folder

FileUtils::mkdir_p OUTPUT
FileUtils::mkdir_p SOURCE

postmanFiles = Dir.glob("#{folder}/*")

output_files = postmanFiles.map do |file| 
	puts "Processing #{file}..."

	json =  File.read(file)
	parsed = JSON.parse(json)
	collection_id = parsed['id']
	collection_name = parsed['name'] || "Collection #{collection_id}"
	collection_description = parsed['description']
	includes = (parsed['order'] || []).map {|request_id| "#{OUTPUT}/api_#{collection_id}_#{request_id}.tex"}

	requests = parsed['requests'] || []
	requests.each do |request|
		request_id = request['id']

		context = Erubis::Context.new
		context[:api_name] = request['name'] || "Request #{request_id}"
		context[:api_description] = request['description']
		context[:api_method] = request['method']
		context[:api_url] = (request['url'] || '').sub '&', "\\\\&"
		context[:headers] = (request['headers'] || '').split(/\n/).map {|h| h.split(':')}	

		request_json = request['rawModeData'] #Parsing request body (if present)
		if request_json.nil?
			context[:request_json] = nil
		else
			request_json_file = "#{SOURCE}/#{collection_id}_#{request_id}.body.json"
			write_listing(request_json_file, request_json)
			context[:request_json] = request_json_file
		end


		responses = request['responses'].each_with_index.map do |response, i| #Parsing response examples
			text = response['text']
			status = "#{response['responseCode']['code']} - #{response['responseCode']['name']}"
			response_file = "#{SOURCE}/#{collection_id}_#{request_id}_#{i}.response.json"
			write_listing(response_file,  JSON.pretty_generate(JSON.parse(text)))
			[status, response_file]
		end
		context[:response_examples] = responses

		process_erb_file("#{TEMPLATE_DIR}/api_template.tex.erb", "#{OUTPUT}/api_#{collection_id}_#{request_id}.tex", context)
	end

	context = Erubis::Context.new
	context[:collection_name] = collection_name
	context[:collection_description] = collection_description
	context[:includes] = includes
	collection_file = "#{OUTPUT}/collection_#{collection_id}.tex"
	process_erb_file("#{TEMPLATE_DIR}/collection_template.tex.erb", collection_file, context)
	collection_file
end

context = Erubis::Context.new
context[:includes] = output_files
process_erb_file("#{TEMPLATE_DIR}/api_chapter_template.tex.erb", "#{OUTPUT}/api_chapter.tex", context)