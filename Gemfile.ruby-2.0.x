source 'https://rubygems.org'

gemspec

gem 'public_suffix', '2.0.5'
gem 'i18n', '1.2.0'
gem 'nokogiri', '1.6.8.1'

group :development do
  gem "rack-test"
  gem "pdf-inspector"
end

group :optional do
  gem "pdfkit"
end

group :test do
  gem 'rake'
  gem 'rspec'
  gem 'pry'
end

gem 'rack-contrib'
