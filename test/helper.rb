require 'rubygems'
require 'test/unit'
require 'mocha'
require 'shoulda-context'

require 'active_record'
require 'logger'
require 'sqlite3'
require 'paperclip'
require 'paperclip-aws'

ROOT       = File.join(File.dirname(__FILE__), '..')
RAILS_ROOT = ROOT
$LOAD_PATH << File.join(ROOT, 'lib')

def silence_warnings
  old_verbose, $VERBOSE = $VERBOSE, nil
  yield
ensure
  $VERBOSE = old_verbose
end

class Test::Unit::TestCase
  def setup
    silence_warnings do
      Object.const_set(:Rails, stub('Rails', :root => ROOT, :env => 'test'))
    end
    Rails.stubs(:const_defined?)
  end
end


FIXTURES_DIR = File.join(File.dirname(__FILE__), "fixtures")
config = YAML::load(IO.read(File.dirname(__FILE__) + '/database.yml'))
ActiveRecord::Base.logger = Logger.new(File.dirname(__FILE__) + "/debug.log")
ActiveRecord::Base.establish_connection(config['test'])
Paperclip.logger = ActiveRecord::Base.logger

# def reset_dummy(options = {})
#   reset_dummy(options)
#   Dummy.new(:image => File.open("#{RAILS_ROOT}/test/fixtures/12k.png"))
# end
def rebuild_model options = {}
  ActiveRecord::Base.connection.create_table :dummies, :force => true do |table|
    table.column :title, :string
    table.column :other, :string
    table.column :avatar_file_name, :string
    table.column :avatar_content_type, :string
    table.column :avatar_file_size, :integer
    table.column :avatar_updated_at, :datetime
    table.column :avatar_fingerprint, :string
  end
  reset_class('Dummy', options)
end

def reset_class(class_name, options)
  ActiveRecord::Base.send(:include, Paperclip::Glue)
  Object.send(:remove_const, class_name) rescue nil
  klass = Object.const_set(class_name, Class.new(ActiveRecord::Base))
  klass.class_eval do
    include Paperclip::Glue
    has_attached_file :avatar, options
  end
  klass.reset_column_information
  klass
end

def fixture_file(filename)
  File.join(File.dirname(__FILE__), 'fixtures', filename)
end