# ======================================================================================
# Template for generating a Rails application with support for Elasticsearch persistence
# ======================================================================================
#
# This file creates a fully working Rails application with support for storing and retrieving models
# in Elasticsearch, using the `elasticsearch-persistence` gem
# (https://github.com/elasticsearch/elasticsearch-rails/tree/master/elasticsearch-persistence).
#
# Requirements:
# -------------
#
# * Git
# * Ruby  >= 1.9.3
# * Rails >= 4
# * Java  >= 7 (for Elasticsearch)
#
# Usage:
# ------
#
#     $ time rails new music --force --skip --skip-bundle --skip-active-record --template /Users/karmi/Contracts/Elasticsearch/Projects/Clients/Ruby/elasticsearch-rails/elasticsearch-persistence/examples/music/template.rb
#
# =====================================================================================================

STDOUT.sync = true
STDERR.sync = true

require 'uri'
require 'net/http'

at_exit do
  pid = File.read("#{destination_root}/tmp/pids/elasticsearch.pid") rescue nil
  if pid
    say_status  "Stop", "Elasticsearch", :yellow
    run "kill #{pid}"
  end
end

run "touch tmp/.gitignore"

append_to_file ".gitignore", "vendor/elasticsearch-1.2.1/\n"

git :init
git add:    "."
git commit: "-m 'Initial commit: Clean application'"

# ----- Download Elasticsearch --------------------------------------------------------------------

unless (Net::HTTP.get(URI.parse('http://localhost:9200')) rescue false)
  COMMAND = <<-COMMAND.gsub(/^    /, '')
    curl -# -O "http://download.elasticsearch.org/elasticsearch/elasticsearch/elasticsearch-1.2.1.tar.gz"
    tar -zxf elasticsearch-1.2.1.tar.gz
    rm  -f   elasticsearch-1.2.1.tar.gz
    ./elasticsearch-1.2.1/bin/elasticsearch -d -p #{destination_root}/tmp/pids/elasticsearch.pid
  COMMAND

  puts        "\n"
  say_status  "ERROR", "Elasticsearch not running!\n", :red
  puts        '-'*80
  say_status  '',      "It appears that Elasticsearch is not running on this machine."
  say_status  '',      "Is it installed? Do you want me to install it for you with this command?\n\n"
  COMMAND.each_line { |l| say_status '', "$ #{l}" }
  puts
  say_status  '',      "(To uninstall, just remove the generated application directory.)"
  puts        '-'*80, ''

  if yes?("Install Elasticsearch?", :bold)
    puts
    say_status  "Install", "Elasticsearch", :yellow

    java_info = `java -version 2>&1`

    unless java_info.match /1\.[7-9]/
      puts
      say_status "ERROR", "Required Java version (1.7) not found, exiting...", :red
      exit(1)
    end

    commands = COMMAND.split("\n")
    exec     = commands.pop
    inside("vendor") do
      commands.each { |command| run command }
      run "(#{exec})"  # Launch Elasticsearch in subshell
    end
  end
end unless ENV['RAILS_NO_ES_INSTALL']

# ----- Add README --------------------------------------------------------------------------------

puts
say_status  "README", "Adding Readme...\n", :yellow
puts        '-'*80, ''; sleep 0.25

remove_file 'README.rdoc'

create_file 'README.rdoc', <<-README
= Ruby on Rails and Elasticsearch persistence: Example application

README


git add:    "."
git commit: "-m 'Added README for the application'"

# ----- Use Thin ----------------------------------------------------------------------------------

begin
  require 'thin'
  puts
  say_status  "Rubygems", "Adding Thin into Gemfile...\n", :yellow
  puts        '-'*80, '';

  gem 'thin'
rescue LoadError
end

# ----- Auxiliary gems ----------------------------------------------------------------------------

# ----- Remove CoffeeScript, Sass and "all that jazz" ---------------------------------------------

comment_lines   'Gemfile', /gem 'coffee/
comment_lines   'Gemfile', /gem 'sass/
comment_lines   'Gemfile', /gem 'uglifier/
uncomment_lines 'Gemfile', /gem 'therubyracer/

# ----- Add gems into Gemfile ---------------------------------------------------------------------

puts
say_status  "Rubygems", "Adding Elasticsearch libraries into Gemfile...\n", :yellow
puts        '-'*80, ''; sleep 0.75

gem "quiet_assets"
gem "simple_form"

gem 'elasticsearch', git: 'git://github.com/elasticsearch/elasticsearch-ruby.git'
gem 'elasticsearch-model', git: 'git://github.com/elasticsearch/elasticsearch-rails.git', require: 'elasticsearch/model'
gem 'elasticsearch-persistence', git: 'git://github.com/elasticsearch/elasticsearch-rails.git', require: 'elasticsearch/persistence/model'
gem 'elasticsearch-rails', git: 'git://github.com/elasticsearch/elasticsearch-rails.git'

git add:    "Gemfile*"
git commit: "-m 'Added libraries into Gemfile'"

# ----- Install gems ------------------------------------------------------------------------------

puts
say_status  "Rubygems", "Installing Rubygems...", :yellow
puts        '-'*80, ''

run "bundle install"

# ----- Autoload ./lib ----------------------------------------------------------------------------

puts
say_status  "Application", "Adding autoloading of ./lib...", :yellow
puts        '-'*80, ''

insert_into_file 'config/application.rb',
                 '
    config.autoload_paths += %W(#{config.root}/lib)

',
                 after: 'class Application < Rails::Application'

git commit: "-a -m 'Added autoloading of the ./lib folder'"

# ----- Add jQuery UI ----------------------------------------------------------------------------

puts
say_status  "Assets", "Adding jQuery UI...", :yellow
puts        '-'*80, ''; sleep 0.25

if ENV['LOCAL']
  copy_file File.expand_path('../vendor/assets/jquery-ui-1.10.4.custom.min.js', __FILE__),
            'vendor/assets/javascripts/jquery-ui-1.10.4.custom.min.js'
  copy_file File.expand_path('../vendor/assets/jquery-ui-1.10.4.custom.min.css', __FILE__),
            'vendor/assets/stylesheets/ui-lightness/jquery-ui-1.10.4.custom.min.css'
else
  get 'https://raw.githubusercontent.com/elasticsearch/elasticsearch-rails/master/elasticsearch-persistence/examples/music/vendor/assets/jquery-ui-1.10.4.custom.min.js',
      'vendor/assets/javascripts/jquery-ui-1.10.4.custom.min.js'
  get 'https://raw.githubusercontent.com/elasticsearch/elasticsearch-rails/master/elasticsearch-persistence/examples/music/vendor/assets/jquery-ui-1.10.4.custom.min.css',
      'vendor/assets/stylesheets/ui-lightness/jquery-ui-1.10.4.custom.min.css'
end

append_to_file 'app/assets/javascripts/application.js', "//= require jquery-ui-1.10.4.custom.min.js"

git commit: "-a -m 'Added jQuery UI'"

# ----- Generate Artist scaffold ------------------------------------------------------------------

puts
say_status  "Model", "Generating the Artist scaffold...", :yellow
puts        '-'*80, ''; sleep 0.25

generate :scaffold, "Artist name:String --orm=elasticsearch"
route "root to: 'artists#index'"

git add:    "."
git commit: "-m 'Added the generated Artist scaffold'"

# ----- Generate Album model ----------------------------------------------------------------------

puts
say_status  "Model", "Generating the Album model...", :yellow
puts        '-'*80, ''; sleep 0.25

generate :model, "Album --orm=elasticsearch"

git add:    "."
git commit: "-m 'Added the generated Album model'"

# ----- Add proper model classes ------------------------------------------------------------------

puts
say_status  "Model", "Adding Album, Artist and Suggester models implementation...", :yellow
puts        '-'*80, ''; sleep 0.25

if ENV['LOCAL']
  copy_file File.expand_path('../artist.rb', __FILE__), 'app/models/artist.rb'
  copy_file File.expand_path('../album.rb', __FILE__), 'app/models/album.rb'
  copy_file File.expand_path('../suggester.rb', __FILE__), 'app/models/suggester.rb'
else
  get 'https://raw.githubusercontent.com/elasticsearch/elasticsearch-rails/master/elasticsearch-persistence/examples/music/artist.rb',
      'app/models/artist.rb'
  get 'https://raw.githubusercontent.com/elasticsearch/elasticsearch-rails/master/elasticsearch-persistence/examples/music/album.rb',
      'app/models/album.rb'
  get 'https://raw.githubusercontent.com/elasticsearch/elasticsearch-rails/master/elasticsearch-persistence/examples/music/suggester.rb',
      'app/models/suggester.rb'
end

git add:    "./app/models"
git commit: "-m 'Added Album, Artist and Suggester models implementation'"

# ----- Add controllers and views -----------------------------------------------------------------

puts
say_status  "Views", "Adding ArtistsController and views...", :yellow
puts        '-'*80, ''; sleep 0.25

if ENV['LOCAL']
  copy_file File.expand_path('../artists/artists_controller.rb', __FILE__), 'app/controllers/artists_controller.rb'
  copy_file File.expand_path('../artists/index.html.erb', __FILE__), 'app/views/artists/index.html.erb'
  copy_file File.expand_path('../artists/show.html.erb', __FILE__), 'app/views/artists/show.html.erb'
  copy_file File.expand_path('../artists/_form.html.erb', __FILE__), 'app/views/artists/_form.html.erb'
  copy_file File.expand_path('../artists/artists_controller_test.rb', __FILE__),
            'test/controllers/artists_controller_test.rb'
else
  get 'https://raw.githubusercontent.com/elasticsearch/elasticsearch-rails/master/elasticsearch-persistence/examples/music/artists/artists_controller.rb',
      'app/controllers/artists_controller.rb'
  get 'https://raw.githubusercontent.com/elasticsearch/elasticsearch-rails/master/elasticsearch-persistence/examples/music/artists/index.html.erb',
      'app/views/artists/index.html.erb'
  get 'https://raw.githubusercontent.com/elasticsearch/elasticsearch-rails/master/elasticsearch-persistence/examples/music/artists/show.html.erb',
      'app/views/artists/show.html.erb'
  get 'https://raw.githubusercontent.com/elasticsearch/elasticsearch-rails/master/elasticsearch-persistence/examples/music/artists/_form.html.erb',
      'app/views/artists/_form.html.erb'
  get 'https://raw.githubusercontent.com/elasticsearch/elasticsearch-rails/master/elasticsearch-persistence/examples/music/artists/artists_controller_test.rb',
      'test/controllers/artists_controller_test.rb'
end

git commit: "-a -m 'Added ArtistsController and related views'"

puts
say_status  "Views", "Adding SearchController and views...", :yellow
puts        '-'*80, ''; sleep 0.25

if ENV['LOCAL']
  copy_file File.expand_path('../search/search_controller.rb', __FILE__), 'app/controllers/search_controller.rb'
  copy_file File.expand_path('../search/search_helper.rb', __FILE__),     'app/helpers/search_helper.rb'
  copy_file File.expand_path('../search/index.html.erb', __FILE__),       'app/views/search/index.html.erb'
  copy_file File.expand_path('../search/search_controller_test.rb', __FILE__),
            'test/controllers/search_controller_test.rb'
else
  get 'https://raw.githubusercontent.com/elasticsearch/elasticsearch-rails/master/elasticsearch-persistence/examples/music/search/search_controller.rb',
      'app/controllers/search_controller.rb'
  get 'https://raw.githubusercontent.com/elasticsearch/elasticsearch-rails/master/elasticsearch-persistence/examples/music/search/search_helper.rb',
      'app/helpers/search_helper.rb'
  get 'https://raw.githubusercontent.com/elasticsearch/elasticsearch-rails/master/elasticsearch-persistence/examples/music/search/index.html.erb',
      'app/views/search/index.html.erb'
  get 'https://raw.githubusercontent.com/elasticsearch/elasticsearch-rails/master/elasticsearch-persistence/examples/music/search/search_controller_test.rb',
      'test/controllers/search_controller_test.rb'
end

route "get 'search',  to: 'search#index'"
route "get 'suggest', to: 'search#suggest'"

comment_lines 'test/test_helper.rb', /fixtures \:all/

git add:    "."
git commit: "-m 'Added SearchController and related views'"

# ----- Add assets -----------------------------------------------------------------

puts
say_status  "Views", "Adding application assets...", :yellow
puts        '-'*80, ''; sleep 0.25

git rm: 'app/assets/stylesheets/scaffold.css'

gsub_file 'app/views/layouts/application.html.erb', /<body>/, '<body class="<%= controller.action_name %>">'

if ENV['LOCAL']
  copy_file File.expand_path('../assets/application.css', __FILE__),  'app/assets/stylesheets/application.css'
  copy_file File.expand_path('../assets/autocomplete.css', __FILE__), 'app/assets/stylesheets/autocomplete.css'
  copy_file File.expand_path('../assets/form.css', __FILE__),         'app/assets/stylesheets/form.css'
  copy_file File.expand_path('../assets/blank_cover.png', __FILE__),  'public/images/blank_cover.png'
else
  get 'https://raw.githubusercontent.com/elasticsearch/elasticsearch-rails/master/elasticsearch-persistence/examples/music/assets/application.css',
      'app/assets/stylesheets/application.css'
  get 'https://raw.githubusercontent.com/elasticsearch/elasticsearch-rails/master/elasticsearch-persistence/examples/music/assets/autocomplete.css',
      'app/assets/stylesheets/autocomplete.css'
  get 'https://raw.githubusercontent.com/elasticsearch/elasticsearch-rails/master/elasticsearch-persistence/examples/music/assets/form.css',
      'app/assets/stylesheets/form.css'
  get 'https://raw.githubusercontent.com/elasticsearch/elasticsearch-rails/master/elasticsearch-persistence/examples/music/assets/blank_cover.png',
      'public/images/blank_cover.png'
end

git add:    "."
git commit: "-m 'Added application assets'"

# ----- Add an Elasticsearch initializer ----------------------------------------------------------

puts
say_status  "Initializer", "Adding an Elasticsearch initializer...", :yellow
puts        '-'*80, ''; sleep 0.25

initializer 'elasticsearch.rb', %q{
  Elasticsearch::Persistence.client = Elasticsearch::Client.new host: ENV['ELASTICSEARCH_URL'] || 'localhost:9200'

  if Rails.env.development?
    logger           = ActiveSupport::Logger.new(STDERR)
    logger.level     = Logger::INFO
    logger.formatter = proc { |s, d, p, m| "\e[2m#{m}\n\e[0m" }
    Elasticsearch::Persistence.client.transport.logger = logger
  end
}.gsub(/^  /, '')

git add:    "./config"
git commit: "-m 'Added an Elasticsearch initializer'"

# ----- Add IndexManager -----------------------------------------------------------------

puts
say_status  "Application", "Adding the IndexManager class...", :yellow
puts        '-'*80, ''; sleep 0.25

if ENV['LOCAL']
  copy_file File.expand_path('../index_manager.rb', __FILE__),  'lib/index_manager.rb'
else
  get 'https://raw.githubusercontent.com/elasticsearch/elasticsearch-rails/master/elasticsearch-persistence/examples/music/index_manager.rb',
      'lib/index_manager.rb'
end

# TODO: get 'https://raw.github.com/...', '...'

git add:    "."
git commit: "-m 'Added the IndexManager class'"

# ----- Import the data ---------------------------------------------------------------------------

puts
say_status  "Data", "Import the data...", :yellow
puts        '-'*80, ''; sleep 0.25

source = ENV.fetch('DATA_SOURCE', 'http://ruby-demo-assets.s3.amazonaws.com/dischord.yml')

run  "rails runner 'IndexManager.import_from_yaml(\"#{source}\", force: true)'"

# ----- Print Git log -----------------------------------------------------------------------------

puts
say_status  "Git", "Details about the application:", :yellow
puts        '-'*80, ''

run "git --no-pager log --reverse --oneline"

# ----- Start the application ---------------------------------------------------------------------

unless ENV['RAILS_NO_SERVER_START']
  require 'net/http'
  if (begin; Net::HTTP.get(URI('http://localhost:3000')); rescue Errno::ECONNREFUSED; false; rescue Exception; true; end)
    puts        "\n"
    say_status  "ERROR", "Some other application is running on port 3000!\n", :red
    puts        '-'*80

    port = ask("Please provide free port:", :bold)
  else
    port = '3000'
  end

  puts  "", "="*80
  say_status  "DONE", "\e[1mStarting the application.\e[0m", :yellow
  puts  "="*80, ""

  run  "rails server --port=#{port}"
end
