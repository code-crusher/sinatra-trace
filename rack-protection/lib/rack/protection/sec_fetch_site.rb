# frozen_string_literal: true

require 'rack/protection'

module Rack
  module Protection
    ##
    # Prevented attack::   CSRF
    # Supported browsers:: Google Chrome 76, Safari 16.4, Firefox 90, Edge 79 and later.
    #                      See https://caniuse.com/mdn-http_headers_sec-fetch-site, for a complete list.
    # More infos::         * https://developer.mozilla.org/en-US/docs/Web/HTTP/Reference/Headers/Sec-Fetch-Site
    #                      * https://developer.chrome.com/blog/fetch-metadata-for-web-developers/
    #
    # Rejects any {unsafe request}[https://httpwg.org/specs/rfc9110.html#safe.methods]
    # whose Sec-Fetch-Site header indicates that it was initiated by a different
    # origin or site than the one being requested.
    #
    # The browser sets this header itself and scripts cannot override it, so a
    # value of <tt>cross-site</tt> or <tt>same-site</tt> on an unsafe request is
    # a strong indication of a cross-site request forgery attempt.
    #
    # Note that browsers only send this header to
    # {potentially trustworthy}[https://w3c.github.io/webappsec-secure-contexts/#potentially-trustworthy-origin]
    # URLs, such as those served over HTTPS or from localhost. Requests without
    # the header are allowed by default, since they generally come from
    # non-browser clients or older browsers, which cannot be tricked into
    # sending a forged request by another site. Set <tt>:allow_missing</tt> to
    # <tt>false</tt> to reject such requests instead.
    #
    # This protection does not use request-specific tokens, so it is weaker
    # than {Rack::Protection::AuthenticityToken}. It is best used together
    # with {Rack::Protection::HttpOrigin}, which covers requests without a
    # Sec-Fetch-Site header by checking the Origin header.
    #
    # This protection is not included by <tt>use Rack::Protection</tt>.
    #
    # == Options
    #
    # [<tt>:allow_missing</tt>] When <tt>true</tt>, unsafe requests without a Sec-Fetch-Site header
    #                           are allowed. Default value is <tt>true</tt>. Set to <tt>false</tt>
    #                           to reject them, which also rejects requests made by non-browser
    #                           clients and by browsers that do not send the header.
    #
    # [<tt>:allow_if</tt>] A Proc to be used for custom logic, superseding the value of
    #                      <tt>:allow_missing</tt> and the Sec-Fetch-Site header. It is not
    #                      evaluated for safe requests. Default value is <tt>nil</tt>.
    #
    # [Rack::Protection::Base options] options supported by Rack::Protection::Base may affect this middleware.
    #
    #
    # == Example: Reject cross-site requests from modern browsers only
    #
    #     use Rack::Protection::SecFetchSite
    #
    # == Example: Reject cross-site requests, including those without the header
    #
    #     use Rack::Protection::SecFetchSite, allow_missing: false
    #
    # == Example: Allow cross-site requests to a webhook endpoint
    #
    #     use Rack::Protection::SecFetchSite,
    #         allow_if: ->(env) { env['PATH_INFO'].start_with?('/webhooks/') }
    #
    class SecFetchSite < Base
      SAFE_VALUES = %w[same-origin none].freeze

      default_reaction :deny
      default_options allow_if: nil, allow_missing: true

      def accepts?(env)
        return true if safe? env
        return true if options[:allow_if]&.call(env)

        value = env['HTTP_SEC_FETCH_SITE']
        return options[:allow_missing] if value.nil?

        SAFE_VALUES.include? value
      end
    end
  end
end
