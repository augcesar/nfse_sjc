require 'erubis'
require 'openssl'
require 'tempfile'

module NfseSjc
  class Document
    def initialize(filepath, params = {})
      @params   = params
      @basename = File.basename filepath
      @schema   = Schemas.get_schema @basename
      @template = load_template(filepath)
    end

    def to_xml
      @template.result(binding)
    end

    def to_signed_xml(signing_params = {})
      signing_params = signing_params.merge(Config.default_config)
      unsigned_xml   = to_xml

      unsigned_temp_xml = Tempfile.new('unsigned-xml')
      signed_temp_xml   = Tempfile.new('signed-xml')
      result            = ''

      begin
        unsigned_temp_xml.write(unsigned_xml)
        unsigned_temp_xml.rewind

        %x{xmlsec1 --sign --privkey-pem '#{signing_params[:ssl_cert_key_file]}','#{signing_params[:ssl_cert_file]}' --output '#{signed_temp_xml.path}' --pwd '#{signing_params[:ssl_cert_key_password]}' '#{unsigned_temp_xml.path}'}

        signed_temp_xml.rewind
        result = signed_temp_xml.read
      ensure
        signed_temp_xml.close
        unsigned_temp_xml.close

        signed_temp_xml.unlink
        unsigned_temp_xml.unlink
      end

      result
    end

    protected

    def render(filepath, params = {}, of: ::NfseSjc::Document)
      of.new(NfseSjc::Dirs.template(filepath), params).to_xml
    end

    def param(*path, with: @params)
      value = with
      path.each do |segment|
        value = value[segment]
        break if value.nil?
      end
      return value
    end

    def if_param(*path, with: @params)
      value = param(*path, with: with)
      yield value unless value.nil? || value.empty?
    end

    private
    def load_template(filepath)
      cachepath = File.join(Dir.tmpdir, "#{@basename}.cache")
      Erubis::FastEruby.load_file(filepath, cachename: cachepath)
    end

    def signing_data(filename)
      @@signing_data ||= {}
      @@signing_data[filename] = File.read(filename) unless @@signing_data[filename]
      @@signing_data[filename]
    end
  end
end