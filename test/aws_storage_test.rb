require './test/helper'

class AwsStorageTest < Test::Unit::TestCase
  def rails_env(env)
    silence_warnings do
      Object.const_set(:Rails, stub('Rails', :env => env))
    end
  end

  context "Parsing S3 credentials" do
    setup do
      @proxy_settings = {:host => "127.0.0.1", :port => 8888, :user => "foo", :password => "bar"}
      Rails.stubs(:const_defined?)
      rebuild_model :storage => :aws,
                    :bucket => "testing",
                    :http_proxy => @proxy_settings,
                    :s3_credentials => {
                      :access_key_id => "ACCESS_KEY_ID",
                      :secret_access_key => "SECRET_ACCESS_KEY"
                    }

      @dummy = Dummy.new
      @avatar = @dummy.avatar
    end
    
    should "get the correct credentials when RAILS_ENV is production" do
      rails_env("production")
      
      assert_equal(
        { :access_key_id => "12345" },
        @avatar.parse_credentials(
          :production => { :access_key_id => '12345' },
          :development => { :access_key_id => '54321' }
        )
      )
    end
    
    should "get the correct credentials when RAILS_ENV is development" do
      rails_env("development")
      
      assert_equal(
        { :access_key_id => "54321" },
        @avatar.parse_credentials(
          :production => { :access_key_id => '12345' },
          :development => { :access_key_id => '54321' }
        )
      )
      
    end
    
  end
end