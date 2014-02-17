[![Build Status](https://secure.travis-ci.org/igor-alexandrov/paperclip-aws.png)](http://travis-ci.org/igor-alexandrov/paperclip-aws)

# Paperclip storage module to use Amazon S3 with official 'aws-sdk' gem #

**paperclip-aws** is a full featured storage module that supports all S3 locations (American, European and Japanese) without any additional hacking.

## Features ##
  
* supports US, European and Japanese S3 instances;
* supports both `http` and `https` urls;
* supports expiring urls;
* supports different permissions for each Paperclip style;
* supports generating urls for `read`, `write` и `delete` operations;
* **supports amazon server side encryption** (thanks to @pvertenten);
* **supports versioning**;
* highly compatible with included in Paperclip S3 storage module


## Requirements ##

* [paperclip][0] ~> 2.6
* [aws-sdk][1] >= 1.2.0

## Installation ##

    gem install paperclip-aws

After this add 'paperclip-aws' to your `Gemfile` or `environment.rb`
    
## Common Usage ##

    class SomeS3Attachment < ActiveRecord::Base
      def self.s3_config
        @@s3_config ||= YAML.load(ERB.new(File.read("#{Rails.root}/config/s3.yml")).result)[Rails.env]    
      end

      has_attached_file :data,
                        :styles => {
                          :thumb => [">75x"],
                          :medium => [">600x"]
                        },                    
                        :storage => :aws,
                        :s3_credentials => {
                          :access_key_id => self.s3_config['access_key_id'],
                          :secret_access_key => self.s3_config['secret_access_key'],
                          :endpoint => self.s3_config['endpoint']
                        },
                        :s3_bucket => self.s3_config['bucket'],                    
                        :s3_host_alias => self.s3_config['s3_host_alias'],
                        :s3_permissions => :public_read,
                        :s3_protocol => 'http',
                        :s3_options => {
                          :server_side_encryption => 'AES256',
                          :storage_class => :reduced_redundancy,
                          :content_disposition => 'attachment'
                        },
                        
                        :path => "company_documents/:id/:style/:data_file_name"  
                        
      # You also can modify :s3_credentials, :s3_bucket, :s3_permissions, :s3_options, :s3_protocol, :s3_host_alias directly in instance.
      before_save do
        self.data.s3_options[:content_disposition] = "attachment; filename=#{self.data_file_name}"
        self.data.s3_options[:server_side_encryption] = true if self.confidential_information?
        self.data.s3_options[:storage_class] = true if self.unimportant_information?
        
        self.data.s3_protocol = 'https' if self.confidential_information?
        
        self.data.s3_permissions = :authenticated_read if self.private?
      end                          
    end

Create link for file that will expire in 10 seconds after it was created. Useful when redirecting user to file.

    file.data.url(:original, { :expires => Time.now + 10.seconds, :protocol => 'https' })

                      
## Configuration ##

### :endpoint ###
Endpoint where your bucket is located. Default is `'s3.amazonaws.com'` which is for 'US Standard' region.

You can find full list of endpoints and regions [here](http://aws.amazon.com/articles/3912#s3)

### :s3_host_alias ###
The CNAME/Alias you have set up for your s3 bucket (e.g. uploads.mysite.com), if you have one.

### :s3_permissions  ###
Sets permissions to your objects. Values are:

    :private
    :public_read
    :public_read_write
    :authenticated_read
    :bucket_owner_read
    :bucket_owner_full_control

You can setup permnissions globally for object or per style:    

    :s3_permissions => :public_read
    
    
    :s3_permissions => {
      :thumb => :public_read,
      :medium => :authenticated_read,
      :default => :authenticated_read
    }
   
### :s3_protocol ###
Default protocol to use: `'http'` or `'https'`.

### :s3_options ###
Hash of additional options. Available options are:

* `:server_side_encryption` –  `'AES256'` (the only available encryption now)
* `:storage_class` – `:standard` (default) or `:reduced_redundancy`
* `:content_disposition`

### :path ###
Remember to specify a folder in a root of your bucket. If you don't , you'll be able to save without problems, 
but S3 will respond with Access Denied on read.

Examples:

* **Bad** (you will get permission denied error)
  *  `:path => "/:style/:id/:filename"`
  *  `:path => "/images/:id/:filename"`

* **Good** (there is a root folder specified)
  *  `:path => "images/:style/:id/:filename"`
  *  `:path => ":style/:id/:filename"`

The main problem of the "Bad" case - it creates nameless folder in a root of a bucket which seems to be an issue when reading, 
so make sure you don't put '/' in front of the path.


## How `paperclip-aws` creates urls? ##

'paperclip-aws' redefines Paperclip `url` method to get object URL.

    def url(style=default_style, options={})
    end

Supported options are:

* `:protocol` — `'http'` or `'https'`

  Use this options to redefine default protocol, configured in model.

* `:expires`

  Sets the expiration time of the URL; after this time S3 will return an error if the URL is used.  This can be an integer (to specify the number of seconds after the current time), a string (which is parsed as a date using Time#parse), a Time, or a DateTime object. This option defaults to one hour after the current time.
  
  Default is set to 3600 seconds.

* `:action`
  
  Method, the HTTP verb or object method for which the returned URL will be valid.  Valid values:
  
  * `:get` or `:read`
  * `:put` or `:write`
  * `:delete`
  
  Default is set to `:read`, which is the most common used.

## Versioning ##

'paperclip-aws' lets you easily use S3 file versioning if it is enabled for selected bucket.
To find more information about versioning and how to enable it, please follow [AWS FAQs](http://aws.amazon.com/s3/faqs/#What_is_Versioning) and [AWS S3 Docs](http://docs.amazonwebservices.com/AmazonS3/latest/dev/Versioning.html).

Also you can enable versioning from your Rails console by using following code:
  
    some_s3_attachment.data.bucket.enable_versioning
  
Please make sure, that user that is used to connect to S3 has enough permissions to do this, or you will get `AWS::S3::Errors::AccessDenied` error.
  
To get array of file versions use #versions method:
  
    some_s3_attachment.data.versions()

## Can I use it in production? ##

Yes, usage of **paperclip-aws** is confirmed by several rather big projects:

* [www.sdelki.ru](http://www.sdelki.ru)
* [www.lienlog.com](http://www.lienlog.com)
* [www.sharypic.com](http://www.sharypic.com)

I hope that it is used in a lot of other projects, if you know them – let me know.

## Note on Patches / Pull Requests

* Fork the project.
* Make your feature addition or bug fix.
* Add tests for it. This is important so I don't break it in a
  future version unintentionally.
* Commit, do not mess with rakefile, version, or history.
  (if you want to have your own version, that is fine but
   bump version in a commit by itself I can ignore when I pull)
* Send me a pull request. Bonus points for topic branches.

## Credits

![JetRockets](http://www.jetrockets.ru/public/logo.png)

Paperclip-AWS is maintained by [JetRockets](http://www.jetrockets.ru/en).

Contributors:

* [Igor Alexandrov](http://igor-alexandrov.github.com/)
* [Alexey Solilin](https://github.com/solilin)

## License

It is free software, and may be redistributed under the terms specified in the LICENSE file.
    
[0]: https://github.com/thoughtbot/paperclip
[1]: https://github.com/amazonwebservices/aws-sdk-for-ruby
