require 'simplecov'
require 'json'
SimpleCov.start

RSpec.configure do |c|
  c.formatter = :documentation
  c.color = true
end

def fixture_path
  File.expand_path('../fixtures', __FILE__)
end

def fixture(f)
  File.new(File.join(fixture_path, f))
end

def fixture_json(f)
  JSON.parse(fixture(f).read)
end

def fixture_db_response(f)
  rs = {}
  allow(rs).to receive(:successful?).and_return(true)
  allow(rs).to receive(:documents).and_return(
    [fixture_json(f)]
  )
  rs
end
