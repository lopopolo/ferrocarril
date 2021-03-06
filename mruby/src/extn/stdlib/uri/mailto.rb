# frozen_string_literal: false

# = uri/mailto.rb
#
# Author:: Akira Yamada <akira@ruby-lang.org>
# License:: You can redistribute it and/or modify it under the same term as Ruby.
# Revision:: $Id$
#
# See URI for general documentation
#

require_relative 'generic'

module URI
  #
  # RFC6068, the mailto URL scheme.
  #
  class MailTo < Generic
    include REGEXP

    # A Default port of nil for URI::MailTo.
    DEFAULT_PORT = nil

    # An Array of the available components for URI::MailTo.
    COMPONENT = %i[scheme to headers].freeze

    # :stopdoc:
    #  "hname" and "hvalue" are encodings of an RFC 822 header name and
    #  value, respectively. As with "to", all URL reserved characters must
    #  be encoded.
    #
    #  "#mailbox" is as specified in RFC 822 [RFC822]. This means that it
    #  consists of zero or more comma-separated mail addresses, possibly
    #  including "phrase" and "comment" components. Note that all URL
    #  reserved characters in "to" must be encoded: in particular,
    #  parentheses, commas, and the percent sign ("%"), which commonly occur
    #  in the "mailbox" syntax.
    #
    #  Within mailto URLs, the characters "?", "=", "&" are reserved.

    # ; RFC 6068
    # hfields      = "?" hfield *( "&" hfield )
    # hfield       = hfname "=" hfvalue
    # hfname       = *qchar
    # hfvalue      = *qchar
    # qchar        = unreserved / pct-encoded / some-delims
    # some-delims  = "!" / "$" / "'" / "(" / ")" / "*"
    #              / "+" / "," / ";" / ":" / "@"
    #
    # ; RFC3986
    # unreserved   = ALPHA / DIGIT / "-" / "." / "_" / "~"
    # pct-encoded  = "%" HEXDIG HEXDIG
    HEADER_REGEXP = /\A(?<hfield>(?:%\h\h|[!$'-.0-;@-Z_a-z~])*=(?:%\h\h|[!$'-.0-;@-Z_a-z~])*)(?:&\g<hfield>)*\z/.freeze
    # practical regexp for email address
    # https://html.spec.whatwg.org/multipage/input.html#valid-e-mail-address
    EMAIL_REGEXP = %r{\A[a-zA-Z0-9.!\#$%&'*+/=?^_`{|}~-]+@[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?(?:\.[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)*\z}.freeze
    # :startdoc:

    #
    # == Description
    #
    # Creates a new URI::MailTo object from components, with syntax checking.
    #
    # Components can be provided as an Array or Hash. If an Array is used,
    # the components must be supplied as <code>[to, headers]</code>.
    #
    # If a Hash is used, the keys are the component names preceded by colons.
    #
    # The headers can be supplied as a pre-encoded string, such as
    # <code>"subject=subscribe&cc=address"</code>, or as an Array of Arrays
    # like <code>[['subject', 'subscribe'], ['cc', 'address']]</code>.
    #
    # Examples:
    #
    #    require 'uri'
    #
    #    m1 = URI::MailTo.build(['joe@example.com', 'subject=Ruby'])
    #    m1.to_s  # => "mailto:joe@example.com?subject=Ruby"
    #
    #    m2 = URI::MailTo.build(['john@example.com', [['Subject', 'Ruby'], ['Cc', 'jack@example.com']]])
    #    m2.to_s  # => "mailto:john@example.com?Subject=Ruby&Cc=jack@example.com"
    #
    #    m3 = URI::MailTo.build({:to => 'listman@example.com', :headers => [['subject', 'subscribe']]})
    #    m3.to_s  # => "mailto:listman@example.com?subject=subscribe"
    #
    def self.build(args)
      tmp = Util.make_components_hash(self, args)

      tmp[:opaque] = case tmp[:to]
                     when Array
                       tmp[:to].join(',')
                     when String
                       tmp[:to].dup
                     else
                       ''
                     end

      if tmp[:headers]
        query =
          case tmp[:headers]
          when Array
            tmp[:headers].collect do |x|
              if x.is_a?(Array)
                x[0] + '=' + x[1..-1].join
              else
                x.to_s
              end
            end.join('&')
          when Hash
            tmp[:headers].collect do |h, v|
              h + '=' + v
            end.join('&')
          else
            tmp[:headers].to_s
          end
        tmp[:opaque] << '?' << query unless query.empty?
      end

      super(tmp)
    end

    #
    # == Description
    #
    # Creates a new URI::MailTo object from generic URL components with
    # no syntax checking.
    #
    # This method is usually called from URI::parse, which checks
    # the validity of each component.
    #
    def initialize(*arg)
      super(*arg)

      @to = nil
      @headers = []

      # The RFC3986 parser does not normally populate opaque
      @opaque = "?#{@query}" if @query && !@opaque

      unless @opaque
        raise InvalidComponentError,
              'missing opaque part for mailto URL'
      end
      to, header = @opaque.split('?', 2)
      # allow semicolon as a addr-spec separator
      # http://support.microsoft.com/kb/820868
      unless /\A(?:[^@,;]+@[^@,;]+(?:\z|[,;]))*\z/ =~ to
        raise InvalidComponentError,
              "unrecognised opaque part for mailtoURL: #{@opaque}"
      end

      if arg[10] # arg_check
        self.to = to
        self.headers = header
      else
        set_to(to)
        set_headers(header)
      end
    end

    # The primary e-mail address of the URL, as a String.
    attr_reader :to

    # E-mail headers set by the URL, as an Array of Arrays.
    attr_reader :headers

    # Checks the to +v+ component.
    def check_to(value)
      return true unless value
      return true if value.empty?

      value.split(/[,;]/).each do |addr|
        # check url safety as path-rootless
        if /\A(?:%\h\h|[!$&-.0-;=@-Z_a-z~])*\z/ !~ addr
          raise InvalidComponentError,
                "an address in 'to' is invalid as URI #{addr.dump}"
        end

        # check addr-spec
        # don't s/\+/ /g
        addr.gsub!(/%\h\h/, URI::TBLDECWWWCOMP_)
        if EMAIL_REGEXP !~ addr
          raise InvalidComponentError,
                "an address in 'to' is invalid as uri-escaped addr-spec #{addr.dump}"
        end
      end

      true
    end
    private :check_to # rubocop:disable Style/AccessModifierDeclarations

    # Private setter for to +v+.
    def set_to(value) # rubocop:disable Naming/AccessorMethodName
      @to = value
    end
    protected :set_to # rubocop:disable Style/AccessModifierDeclarations

    # Setter for to +v+.
    def to=(value)
      check_to(value)
      set_to(value)
      value # rubocop:disable Lint/Void
    end

    # Checks the headers +v+ component against either
    # * HEADER_REGEXP
    def check_headers(headers)
      return true unless headers
      return true if headers.empty?

      if HEADER_REGEXP !~ headers
        raise InvalidComponentError,
              "bad component(expected opaque component): #{headers}"
      end

      true
    end
    private :check_headers # rubocop:disable Style/AccessModifierDeclarations

    # Private setter for headers +v+.
    def set_headers(headers) # rubocop:disable Naming/AccessorMethodName
      @headers = []
      headers&.split('&')&.each do |x|
        @headers << x.split(/=/, 2)
      end
    end
    protected :set_headers # rubocop:disable Style/AccessModifierDeclarations

    # Setter for headers +v+.
    def headers=(headers)
      check_headers(headers)
      set_headers(headers)
      headers # rubocop:disable Lint/Void
    end

    # Constructs String from URI.
    def to_s
      @scheme + ':' +
        (@to || '') +
        if !@headers.empty?
          '?' + @headers.collect { |x| x.join('=') }.join('&')
        else
          ''
        end +
        if @fragment
          '#' + @fragment
        else
          ''
        end
    end

    # Returns the RFC822 e-mail text equivalent of the URL, as a String.
    #
    # Example:
    #
    #   require 'uri'
    #
    #   uri = URI.parse("mailto:ruby-list@ruby-lang.org?Subject=subscribe&cc=myaddr")
    #   uri.to_mailtext
    #   # => "To: ruby-list@ruby-lang.org\nSubject: subscribe\nCc: myaddr\n\n\n"
    #
    def to_mailtext
      to = URI.decode_www_form_component(@to)
      head = ''
      body = ''
      @headers.each do |x|
        case x[0]
        when 'body'
          body = URI.decode_www_form_component(x[1])
        when 'to'
          to << ', ' + URI.decode_www_form_component(x[1])
        else
          head << URI.decode_www_form_component(x[0]).capitalize + ': ' +
                  URI.decode_www_form_component(x[1]) + "\n"
        end
      end

      "To: #{to}
#{head}
#{body}
"
    end
    alias to_rfc822text to_mailtext
  end

  @@schemes['MAILTO'] = MailTo
end
